// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {OrderTypes} from "../OrderTypes.sol";

interface IPurchase {
    // Errors
    error MinimumExpirationAtMustBeLessThanMaximumExpirationTime();

    error AddressCannotBeAddressZero();

    error AddressMustImplementITransferManager();

    error IsNotOwnerOfNftContractAndTokenId(address nftContract, uint256 tokenId);

    error TransferManagerIsNotApprovedInNftContractAndTokenId(address nftContract, uint256 tokenId);
    error OrderInProgress(address nftContract, uint256 tokenId);
    error AmountCannotBeZero();
    error CurrencyCannotBeAddressZero();
    error TokensIdsCannotBeEmpty();
    error OrderDoesNotExist(uint256 orderId);
    error ReceiverIsOwnerOfNftContractAndTokenId(address nftContract, uint256 tokenId);
    error OrderExpired(uint256 orderId);
    error AmountDoesNotMatchCurrentPrice(uint256 orderId, uint256 amount, uint256 currentPrice);
    error OrderDoesNotMatchOwnerOfNftContractAndTokenId(
        uint256 orderId,
        address nftContract,
        uint256 tokenId,
        address owner,
        address originalOwner
    );
    error TokenIdAlreadySold(uint256 orderId, uint256 tokenId);

    error NotSoldForThatCurrency(uint256 orderId, address currency);

    error CurrencyCannotBeUsedMoreThanOnce(address currency);

    error InsufficientFunds(address currency, address from, address to, uint256 amount);

    error YouNoHasPermission();


    error ExpirationTimeMustBeGreaterThanMinimumExpirationTime(
        uint256 expirationTimeExtension,
        uint256 minimumExpirationTime
    );

    error ExpirationTimeMustBeLessThanMaximumExpirationTime(
        uint256 expirationTimeExtension,
        uint256 maximumExpirationTime
    );

    error CurrenciesAndPricesMustHaveSameLength();

    // Events
    event UpdatedExpirationTime(uint256 minimumExpirationTime, uint256 maximumExpirationTime);

    event OrderCommerceCreated(
        uint256 indexed orderId,
        address indexed nftContract,
        uint256[] tokensIds,
        uint256 amount,
        address[] erc20Addresses,
        uint256[] erc20Amounts,
        uint256 expirationTime
    );

    event OrderCommercePurchased(
        uint256 indexed orderId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address payee,
        uint256 amount,
        address currency
    );

    event RoyaltyPayment(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed royaltyRecipient,
        uint256 amount
    );

    event NewTreasury(address indexed treasury);

    event NewTransferManager(address indexed transferManager);

    event NewCommerceSignaturePurchase(address indexed verifySignature);

    event OrderCommerceCancelled(uint256 indexed orderId);

    event OrderCommerceCurrenciesUpdated(
        uint256 indexed orderId,
        uint256 amount,
        address[] erc20Addresses,
        uint256[] erc20Amounts
    );

    event OrderCommerceTokensUpdated(uint256 indexed orderId, uint256[] tokensIds);

    event OrderCommerceExpirationTimeUpdated(uint256 indexed orderId, uint256 expirationTime);

    function initialize(
        address payable _treasury,
        address _transferManager,
        address _verifySignature
    ) external;

    function updateMiniumAndMaximumExpirationTime(uint256 _minimumExpirationTime, uint256 _maximumExpirationTime)
        external;

    function setTreasury(address payable _treasury) external;

    function setTransferManager(address _transferManager) external;

    function setCommerceSignaturePurchase(address _verifySignature) external;

    function getOrderByContractAndToken(address nftContract, uint256 tokenId) external view returns (uint256);

    function isApproved(
        address nftContract,
        uint256 tokenId,
        address _address
    ) external view returns (bool);

    function getRoyaltyInfo(
        address nftContract,
        uint256 tokenId,
        uint256 amount
    ) external view returns (address receiver, uint256 royaltyAmount);

    function getOrder(uint256 orderId)
        external
        view
        returns (
            OrderTypes.Order memory order,
            address createdBy,
            uint256[] memory tokensIdsSold,
            uint256 checkpoint
        );

    function createOrder(
        OrderTypes.Order memory request,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external;

    function canCreateOrder(OrderTypes.Order memory request, address requester) external view;

    function updateOrderTokens(
        uint256 orderId,
        uint256[] calldata tokensIds,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external;

    function canUpdateOrderTokens(
        uint256 orderId,
        uint256[] calldata tokensIds,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external view;

    function isApprovedToNftContractAndTokensIds(
        uint256 orderId,
        address nftContract,
        uint256[] memory tokensIds,
        address requester
    ) external view;

    function cancelOrder(
        uint256 orderId,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external;

    function canCancelOrder(
        uint256 orderId,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external view;

    function updateOrderCurrency(
        uint256 orderId,
        uint256 amount,
        address[] calldata erc20Addresses,
        uint256[] calldata erc20Amounts,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external;

    function canUpdateOrderCurrency(
        uint256 orderId,
        uint256 amount,
        address[] calldata erc20Addresses,
        uint256[] calldata erc20Amounts,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external view;

    function updatedOrderExpirationTime(
        uint256 orderId,
        uint256 expirationTimeExtension,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external;

    function canUpdateOrderExpirationTime(
        uint256 orderId,
        uint256 expirationTimeExtension,
        address requester,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external view;

    function buy(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external payable;

    function canBuy(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        uint256 amount,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external view;

    function buyWithCurrency(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        address currency,
        uint256 amount,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external;

    function canBuyWithCurrency(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        address currency,
        uint256 amount,
        uint256 signatureExpiresAt,
        bytes memory signature
    ) external view;
}
