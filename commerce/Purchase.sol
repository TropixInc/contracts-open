// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";

import {IERC2981Upgradeable, IERC165Upgradeable} from "./interfaces/IERC2981Upgradeable.sol";

import {ITransferManager} from "../transfer-manager/ITransferManager.sol";

import {ICommerceSignaturePurchase} from "./interfaces/ICommerceSignaturePurchase.sol";
import {IPurchase} from "./interfaces/IPurchase.sol";

import {ManagerETH} from "./ManagerETH.sol";

import {OrderTypes} from "./OrderTypes.sol";

contract Purchase is
    IPurchase,
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ManagerETH
{
    using AddressUpgradeable for address payable;
    using SafeMathUpgradeable for uint256;
    using OrderTypes for OrderTypes.Order;

    uint256 internal constant _BASIS_POINTS = 10000;
    bytes4 internal constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    bytes4 internal constant _INTERFACE_ID_TRANSFER_MANAGER =
        bytes4(keccak256("transferFromERC721(address,address,address,uint256)"));

    address payable public treasury;
    address public transferManager;
    uint256 private _nextOrderId;
    uint256 public minimumExpirationTime;
    uint256 public maximumExpirationTime;
    address public verifySignature;

    mapping(uint256 => OrderTypes.Order) private _orderIdToOrder;
    mapping(uint256 => mapping(uint256 => address)) private _orderIdAndTokenIdToOriginalOwner;
    mapping(uint256 => uint256) private _orderIdToCheckpoint;
    mapping(uint256 => mapping(address => uint256)) private _orderIdToCurrenciesMap;
    mapping(address => mapping(uint256 => mapping(address => uint256))) private _nftContractToTokenIdToOrderId;

    mapping(uint256 => mapping(uint256 => bool)) private _orderIdAndTokenIdsSold;
    mapping(uint256 => mapping(uint256 => bool)) private _orderIdAndTokensIdsForSale;
    mapping(uint256 => uint256[]) private _orderIdTokensIdsSold;

    mapping(uint256 => address) private _orderIdCreatedBy;

    function initialize(
        address payable _treasury,
        address _transferManager,
        address _verifySignature
    ) external initializer {
        if (_treasury == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        if (_transferManager == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        if (_verifySignature == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        if (ITransferManager(_transferManager).supportsInterface(_INTERFACE_ID_TRANSFER_MANAGER) == false) {
            revert AddressMustImplementITransferManager();
        }
        treasury = _treasury;
        transferManager = _transferManager;
        verifySignature = _verifySignature;
        _nextOrderId = 1;
        minimumExpirationTime = 1 days;
        maximumExpirationTime = 180 days;

        __Ownable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function updateMiniumAndMaximumExpirationTime(uint256 _minimumExpirationTime, uint256 _maximumExpirationTime)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_minimumExpirationTime >= _maximumExpirationTime) {
            revert MinimumExpirationAtMustBeLessThanMaximumExpirationTime();
        }
        minimumExpirationTime = _minimumExpirationTime;
        maximumExpirationTime = _maximumExpirationTime;
        emit UpdatedExpirationTime(_minimumExpirationTime, _maximumExpirationTime);
    }

    function setTreasury(address payable _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        treasury = _treasury;
        emit NewTreasury(_treasury);
    }

    function setTransferManager(address _transferManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_transferManager == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        if (ITransferManager(_transferManager).supportsInterface(_INTERFACE_ID_TRANSFER_MANAGER) == false) {
            revert AddressMustImplementITransferManager();
        }
        transferManager = _transferManager;
        emit NewTransferManager(_transferManager);
    }

    function setCommerceSignaturePurchase(address _verifySignature) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_verifySignature == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        verifySignature = _verifySignature;
        emit NewCommerceSignaturePurchase(_verifySignature);
    }

    function createOrder(
        OrderTypes.Order memory request,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external nonReentrant {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createOrderHash(request, signatureExpiresAt);
        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);
        uint256 orderId = _createOrder(request);
        _orderIdCreatedBy[orderId] = _msgSender();
    }

    function updateOrderTokens(
        uint256 orderId,
        uint256[] calldata tokensIds,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external {
        canUpdateOrderTokens(orderId, tokensIds, _msgSender(), signatureExpiresAt, signature);

        OrderTypes.Order memory order = _orderIdToOrder[orderId];

        for (uint256 i = 0; i < order.tokensIds.length; i++) {
            address owner = _orderIdAndTokenIdToOriginalOwner[orderId][order.tokensIds[i]];
            delete _orderIdAndTokenIdToOriginalOwner[orderId][order.tokensIds[i]];
            delete _nftContractToTokenIdToOrderId[order.nftContract][order.tokensIds[i]][owner];

            delete _orderIdAndTokensIdsForSale[orderId][order.tokensIds[i]];
            delete _nftContractToTokenIdToOrderId[order.nftContract][order.tokensIds[i]][owner];
        }

        _saveReferencesOrderAndTokensIds(orderId, order.nftContract, tokensIds);

        _orderIdToOrder[orderId].tokensIds = tokensIds;
        emit OrderCommerceTokensUpdated(orderId, tokensIds);
    }

    function cancelOrder(
        uint256 orderId,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external nonReentrant {
        canCancelOrder(orderId, _msgSender(), signatureExpiresAt, signature);

        OrderTypes.Order memory order = _orderIdToOrder[orderId];

        for (uint256 i = 0; i < order.tokensIds.length; i++) {
            address owner = _orderIdAndTokenIdToOriginalOwner[orderId][order.tokensIds[i]];
            delete _orderIdAndTokenIdToOriginalOwner[orderId][order.tokensIds[i]];
            delete _nftContractToTokenIdToOrderId[order.nftContract][order.tokensIds[i]][owner];

            delete _orderIdAndTokensIdsForSale[orderId][order.tokensIds[i]];
            delete _nftContractToTokenIdToOrderId[order.nftContract][order.tokensIds[i]][owner];
            delete _orderIdAndTokenIdsSold[orderId][order.tokensIds[i]];
        }

        for (uint256 i = 0; i < order.erc20Addresses.length; i++) {
            delete _orderIdToCurrenciesMap[orderId][order.erc20Addresses[i]];
        }

        delete _orderIdToOrder[orderId];
        delete _orderIdCreatedBy[orderId];
        delete _orderIdTokensIdsSold[orderId];
        delete _orderIdToCheckpoint[orderId];

        emit OrderCommerceCancelled(orderId);
    }

    function updateOrderCurrency(
        uint256 orderId,
        uint256 amount,
        address[] calldata erc20Addresses,
        uint256[] calldata erc20Amounts,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external {
        canUpdateOrderCurrency(
            orderId,
            amount,
            erc20Addresses,
            erc20Amounts,
            _msgSender(),
            signatureExpiresAt,
            signature
        );

        for (uint256 i = 0; i < _orderIdToOrder[orderId].erc20Addresses.length; i++) {
            delete _orderIdToCurrenciesMap[orderId][_orderIdToOrder[orderId].erc20Addresses[i]];
        }

        for (uint256 i = 0; i < erc20Addresses.length; i++) {
            if (_orderIdToCurrenciesMap[orderId][erc20Addresses[i]] != 0) {
                revert CurrencyCannotBeUsedMoreThanOnce({currency: erc20Addresses[i]});
            }
            _orderIdToCurrenciesMap[orderId][erc20Addresses[i]] = erc20Amounts[i];
        }

        _orderIdToOrder[orderId].amount = amount;
        _orderIdToOrder[orderId].erc20Addresses = erc20Addresses;
        _orderIdToOrder[orderId].erc20Amounts = erc20Amounts;
        emit OrderCommerceCurrenciesUpdated(orderId, amount, erc20Addresses, erc20Amounts);
    }

    function buy(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external payable nonReentrant {
        canBuy(orderId, tokenId, receiver, msg.value, signatureExpiresAt, signature);
        OrderTypes.Order memory order = _orderIdToOrder[orderId];

        uint256 royaltyFeeAmount;
        uint256 amount = msg.value;

        uint256 marketFee = _payMarket(amount, order.fee);

        if (order.payRoyalty) {
            (, royaltyFeeAmount) = _payRoyalty(order.nftContract, tokenId, amount.sub(marketFee));
        }

        uint256 remainderAmount = amount.sub(marketFee).sub(royaltyFeeAmount);

        _sendValueWithFallbackWithdrawWithMediumGasLimit(payable(order.payee), remainderAmount);

        _buy(orderId, order.nftContract, tokenId, amount, address(0), order.payee, receiver);
    }

    function updatedOrderExpirationTime(
        uint256 orderId,
        uint256 expirationTimeExtension,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external {
        canUpdateOrderExpirationTime(orderId, expirationTimeExtension, _msgSender(), signatureExpiresAt, signature);
        _orderIdToCheckpoint[orderId] = block.timestamp;
        _orderIdToOrder[orderId].expirationTime = expirationTimeExtension;
        emit OrderCommerceExpirationTimeUpdated(orderId, expirationTimeExtension);
    }

    function buyWithCurrency(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        address currency,
        uint256 amount,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external nonReentrant {
        OrderTypes.Order memory order = _orderIdToOrder[orderId];

        if (order.nftContract == address(0)) {
            revert OrderDoesNotExist({orderId: orderId});
        }

        if (receiver != _msgSender()) {
            revert YouNoHasPermission();
        }

        canBuyWithCurrency(orderId, tokenId, receiver, currency, amount, signatureExpiresAt, signature);

        ITransferManager(transferManager).transferFromERC20(currency, receiver, transferManager, amount);

        uint256 royaltyFeeAmount;

        uint256 marketFee = _payMarket(amount, order.fee, currency);

        if (order.payRoyalty) {
            (, royaltyFeeAmount) = _payRoyalty(order.nftContract, tokenId, amount.sub(marketFee), currency);
        }

        uint256 remainderAmount = amount.sub(marketFee).sub(royaltyFeeAmount);

        ITransferManager(transferManager).transferERC20(currency, order.payee, remainderAmount);

        _buy(orderId, order.nftContract, tokenId, amount, currency, order.payee, receiver);
    }

    function getOrder(uint256 orderId)
        external
        view
        returns (
            OrderTypes.Order memory order,
            address createdBy,
            uint256[] memory tokensIdsSold,
            uint256 checkpoint
        )
    {
        order = _orderIdToOrder[orderId];
        createdBy = _orderIdCreatedBy[orderId];
        tokensIdsSold = _orderIdTokensIdsSold[orderId];
        checkpoint = _orderIdToCheckpoint[orderId];
    }

    function getOrderByContractAndToken(address nftContract, uint256 tokenId) public view returns (uint256) {
        address owner = IERC721Upgradeable(nftContract).ownerOf(tokenId);
        return _nftContractToTokenIdToOrderId[nftContract][tokenId][owner];
    }

    function isApproved(
        address nftContract,
        uint256 tokenId,
        address _address
    ) public view returns (bool) {
        address owner = IERC721Upgradeable(nftContract).ownerOf(tokenId);
        return
            IERC721Upgradeable(nftContract).isApprovedForAll(owner, _address) ||
            IERC721Upgradeable(nftContract).getApproved(tokenId) == _address;
    }

    function getRoyaltyInfo(
        address nftContract,
        uint256 tokenId,
        uint256 amount
    ) public view returns (address receiver, uint256 royaltyAmount) {
        if (IERC165Upgradeable(nftContract).supportsInterface(_INTERFACE_ID_ERC2981)) {
            (receiver, royaltyAmount) = IERC2981Upgradeable(nftContract).royaltyInfo(tokenId, amount);
        }
        return (receiver, royaltyAmount);
    }

    function canCreateOrder(OrderTypes.Order memory request, address requester) public view {
        if (request.amount == 0 && request.erc20Addresses.length == 0) {
            revert AmountCannotBeZero();
        }
        if (request.expirationTime < minimumExpirationTime) {
            revert ExpirationTimeMustBeGreaterThanMinimumExpirationTime({
                expirationTimeExtension: request.expirationTime,
                minimumExpirationTime: minimumExpirationTime
            });
        }
        if (request.expirationTime > maximumExpirationTime) {
            revert ExpirationTimeMustBeLessThanMaximumExpirationTime({
                expirationTimeExtension: request.expirationTime,
                maximumExpirationTime: maximumExpirationTime
            });
        }

        if (request.erc20Addresses.length != request.erc20Amounts.length) {
            revert CurrenciesAndPricesMustHaveSameLength();
        }

        for (uint256 i = 0; i < request.erc20Addresses.length; i++) {
            if (request.erc20Addresses[i] == address(0)) {
                revert CurrencyCannotBeAddressZero();
            }
            if (request.erc20Amounts[i] == 0) {
                revert AmountCannotBeZero();
            }
        }
        isApprovedToNftContractAndTokensIds(0, request.nftContract, request.tokensIds, requester);
    }

    function canUpdateOrderTokens(
        uint256 orderId,
        uint256[] calldata tokensIds,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) public view {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createUpdateOrderTokensHash(
            orderId,
            tokensIds,
            requester,
            signatureExpiresAt
        );

        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);

        if (_orderIdToOrder[orderId].nftContract == address(0)) {
            revert OrderDoesNotExist({orderId: orderId});
        }
     
        isApprovedToNftContractAndTokensIds(orderId, _orderIdToOrder[orderId].nftContract, tokensIds, requester);
    }

    function isApprovedToNftContractAndTokensIds(
        uint256 orderId,
        address nftContract,
        uint256[] memory tokensIds,
        address requester
    ) public view {
        if (tokensIds.length == 0) {
            revert TokensIdsCannotBeEmpty();
        }
        for (uint256 i = 0; i < tokensIds.length; i++) {
            if (orderId != 0 && _orderIdAndTokenIdsSold[orderId][tokensIds[i]]) {
                continue;
            }
            uint256 orderTokenId = getOrderByContractAndToken(nftContract, tokensIds[i]);
            if (orderTokenId != orderId && orderTokenId != 0) {
                revert OrderInProgress({nftContract: nftContract, tokenId: tokensIds[i]});
            }
            bool transferManagerIsApproved = isApproved(nftContract, tokensIds[i], transferManager);
            if (!transferManagerIsApproved) {
                revert TransferManagerIsNotApprovedInNftContractAndTokenId({
                    nftContract: nftContract,
                    tokenId: tokensIds[i]
                });
            }

            bool senderIsApproved = isApproved(nftContract, tokensIds[i], requester);
            if (senderIsApproved) {
                continue;
            }

            _checkOwner(nftContract, tokensIds[i], requester);
        }
    }

    function canCancelOrder(
        uint256 orderId,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) public view {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createOrderIdHash(
            orderId,
            requester,
            signatureExpiresAt
        );
        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);

        if (_orderIdToOrder[orderId].nftContract == address(0)) {
            revert OrderDoesNotExist({orderId: orderId});
        }
    }

    function canUpdateOrderCurrency(
        uint256 orderId,
        uint256 amount,
        address[] calldata erc20Addresses,
        uint256[] calldata erc20Amounts,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) public view {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createUpdateOrderCurrencyHash(
            orderId,
            amount,
            erc20Addresses,
            erc20Amounts,
            requester,
            signatureExpiresAt
        );
        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);
        if (_orderIdToOrder[orderId].nftContract == address(0)) {
            revert OrderDoesNotExist({orderId: orderId});
        }
        if (amount == 0 && erc20Addresses.length == 0) {
            revert AmountCannotBeZero();
        }

        for (uint256 i = 0; i < erc20Addresses.length; i++) {
            if (erc20Addresses[i] == address(0)) {
                revert CurrencyCannotBeAddressZero();
            }
            if (erc20Amounts[i] == 0) {
                revert AmountCannotBeZero();
            }
        }
    }

    function canUpdateOrderExpirationTime(
        uint256 orderId,
        uint256 expirationTimeExtension,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) public view {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createUpdateOrderExpirationTimeHash(
            orderId,
            expirationTimeExtension,
            requester,
            signatureExpiresAt
        );
        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);
        if (_orderIdToOrder[orderId].nftContract == address(0)) {
            revert OrderDoesNotExist({orderId: orderId});
        }
        if (expirationTimeExtension < minimumExpirationTime) {
            revert ExpirationTimeMustBeGreaterThanMinimumExpirationTime({
                expirationTimeExtension: expirationTimeExtension,
                minimumExpirationTime: minimumExpirationTime
            });
        }
        if (expirationTimeExtension > maximumExpirationTime) {
            revert ExpirationTimeMustBeLessThanMaximumExpirationTime({
                expirationTimeExtension: expirationTimeExtension,
                maximumExpirationTime: maximumExpirationTime
            });
        }
    }

    function canBuy(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        uint256 amount,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) public view {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createBuyHash(
            orderId,
            tokenId,
            receiver,
            amount,
            signatureExpiresAt
        );
        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);
        OrderTypes.Order memory order = _orderIdToOrder[orderId];

        if (order.nftContract == address(0)) {
            revert OrderDoesNotExist({orderId: orderId});
        }

        if (order.amount == 0) {
            revert NotSoldForThatCurrency({orderId: orderId, currency: address(0)});
        }

        if (amount != order.amount) {
            revert AmountDoesNotMatchCurrentPrice({orderId: orderId, amount: amount, currentPrice: order.amount});
        }
        _canBuy(orderId, tokenId, receiver);
    }

    function canBuyWithCurrency(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        address currency,
        uint256 amount,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) public view {
        bytes32 messageHash = ICommerceSignaturePurchase(verifySignature).createBuyWithCurrencyHash(
            orderId,
            tokenId,
            receiver,
            currency,
            amount,
            signatureExpiresAt
        );
        ICommerceSignaturePurchase(verifySignature).checkSignature(messageHash, signature, signatureExpiresAt);
        if (_orderIdToCurrenciesMap[orderId][currency] == 0) {
            revert NotSoldForThatCurrency({orderId: orderId, currency: currency});
        }
        if (amount != _orderIdToCurrenciesMap[orderId][currency]) {
            revert AmountDoesNotMatchCurrentPrice({
                orderId: orderId,
                amount: amount,
                currentPrice: _orderIdToCurrenciesMap[orderId][currency]
            });
        }

        bool hasAllowance = ITransferManager(transferManager).hasAllowance(currency, receiver, transferManager, amount);

        if (hasAllowance == false) {
            revert InsufficientFunds({currency: currency, amount: amount, to: transferManager, from: receiver});
        }
        _canBuy(orderId, tokenId, receiver);
    }

    function _buy(
        uint256 orderId,
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address currency,
        address payee,
        address receiver
    ) private {
        ITransferManager(transferManager).transferFromERC721(
            nftContract,
            _orderIdAndTokenIdToOriginalOwner[orderId][tokenId],
            receiver,
            tokenId
        );

        emit OrderCommercePurchased(orderId, nftContract, tokenId, payee, receiver, amount, currency);

        _orderIdAndTokenIdsSold[orderId][tokenId] = true;
        _orderIdTokensIdsSold[orderId].push(tokenId);

        _cleanOrderReference(orderId, tokenId);
    }

    function _canBuy(
        uint256 orderId,
        uint256 tokenId,
        address receiver
    ) private view {
        OrderTypes.Order memory order = _orderIdToOrder[orderId];

        if (_orderIdAndTokenIdsSold[orderId][tokenId]) {
            revert TokenIdAlreadySold({orderId: orderId, tokenId: tokenId});
        }

        address owner = IERC721Upgradeable(order.nftContract).ownerOf(tokenId);

        if (owner == receiver) {
            revert ReceiverIsOwnerOfNftContractAndTokenId({nftContract: order.nftContract, tokenId: tokenId});
        }

        if (_orderIdAndTokenIdToOriginalOwner[orderId][tokenId] != owner) {
            revert OrderDoesNotMatchOwnerOfNftContractAndTokenId({
                orderId: orderId,
                nftContract: order.nftContract,
                tokenId: tokenId,
                owner: owner,
                originalOwner: _orderIdAndTokenIdToOriginalOwner[orderId][tokenId]
            });
        }

        if ((order.expirationTime + _orderIdToCheckpoint[orderId]) < block.timestamp) {
            revert OrderExpired({orderId: orderId});
        }
    }

    function _cleanOrderReference(uint256 orderId, uint256 tokenId) private {
        delete _orderIdAndTokenIdToOriginalOwner[orderId][tokenId];
    }

    function _payMarket(uint256 amount, uint256 _fee) private returns (uint256 marketFee) {
        if (_fee > 0) {
            marketFee = amount.mul(_fee) / _BASIS_POINTS;
            _deposit(treasury, marketFee);
        }
    }

    function _payMarket(
        uint256 amount,
        uint256 _fee,
        address currency
    ) private returns (uint256 marketFee) {
        if (_fee > 0 && currency != address(0)) {
            marketFee = amount.mul(_fee) / _BASIS_POINTS;
            ITransferManager(transferManager).transferERC20(currency, treasury, marketFee);
        }
    }

    function _payRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 amount
    ) private returns (address royaltyFeeRecipient, uint256 royaltyFeeAmount) {
        (royaltyFeeRecipient, royaltyFeeAmount) = getRoyaltyInfo(nftContract, tokenId, amount);
        if (royaltyFeeRecipient != address(0) && royaltyFeeAmount != 0) {
            _sendValueWithFallbackWithdrawWithMediumGasLimit(payable(royaltyFeeRecipient), royaltyFeeAmount);
            emit RoyaltyPayment(nftContract, tokenId, royaltyFeeRecipient, royaltyFeeAmount);
        }
    }

    function _payRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address currency
    ) private returns (address royaltyFeeRecipient, uint256 royaltyFeeAmount) {
        (royaltyFeeRecipient, royaltyFeeAmount) = getRoyaltyInfo(nftContract, tokenId, amount);
        if (royaltyFeeRecipient != address(0) && royaltyFeeAmount != 0 && currency != address(0)) {
            ITransferManager(transferManager).transferERC20(currency, royaltyFeeRecipient, royaltyFeeAmount);
            emit RoyaltyPayment(nftContract, tokenId, royaltyFeeRecipient, royaltyFeeAmount);
        }
    }

    function _getNextAndIncrementOrderId() private returns (uint256) {
        return _nextOrderId++;
    }

    function _checkOwner(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) private view {
        if (IERC721Upgradeable(_nftContract).ownerOf(_tokenId) != _owner) {
            revert IsNotOwnerOfNftContractAndTokenId({nftContract: _nftContract, tokenId: _tokenId});
        }
    }

    function _createOrder(OrderTypes.Order memory request) private returns (uint256 orderId) {
        canCreateOrder(request, _msgSender());

        orderId = _getNextAndIncrementOrderId();

        _saveReferencesOrderAndTokensIds(orderId, request.nftContract, request.tokensIds);

        _orderIdToOrder[orderId] = request;

        _orderIdToCheckpoint[orderId] = block.timestamp;

        for (uint256 i = 0; i < request.erc20Addresses.length; i++) {
            if (_orderIdToCurrenciesMap[orderId][request.erc20Addresses[i]] != 0) {
                revert CurrencyCannotBeUsedMoreThanOnce({currency: request.erc20Addresses[i]});
            }
            _orderIdToCurrenciesMap[orderId][request.erc20Addresses[i]] = request.erc20Amounts[i];
        }

        emit OrderCommerceCreated(
            orderId,
            request.nftContract,
            request.tokensIds,
            request.amount,
            request.erc20Addresses,
            request.erc20Amounts,
            request.expirationTime
        );
    }

    function _saveReferencesOrderAndTokensIds(
        uint256 orderId,
        address nftContract,
        uint256[] memory tokensIds
    ) private {
        for (uint256 i = 0; i < tokensIds.length; i++) {
            address owner = IERC721Upgradeable(nftContract).ownerOf(tokensIds[i]);
            _orderIdAndTokenIdToOriginalOwner[orderId][tokensIds[i]] = owner;
            _nftContractToTokenIdToOrderId[nftContract][tokensIds[i]][owner] = orderId;

            _orderIdAndTokensIdsForSale[orderId][tokensIds[i]] = true;
        }
    }
}
