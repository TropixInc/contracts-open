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

import {ManagerETH} from "./ManagerETH.sol";

import {IWeblockNftMarketplace} from "./interfaces/IWeblockNftMarketplace.sol";

contract WeblockNftMarketplace is
    IWeblockNftMarketplace,
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ManagerETH
{
    using AddressUpgradeable for address payable;
    using SafeMathUpgradeable for uint256;

    uint256 internal constant _BASIS_POINTS_PER_PERCENTAGE = 10000;
    bytes4 internal constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    bytes4 internal constant _INTERFACE_ID_TRANSFER_MANAGER =
        bytes4(keccak256("transferFromERC721(address,address,address,uint256)"));

    address payable public treasury;
    address public transferManager;
    address public trustedWallet;

    mapping(uint32 => bool) private externalIdsAlreadyUsed;

    function initialize(
        address payable _treasury,
        address _transferManager,
        address _trustedWallet
    ) external initializer {
        if (_treasury == address(0) || _transferManager == address(0) || _trustedWallet == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        if (ITransferManager(_transferManager).supportsInterface(_INTERFACE_ID_TRANSFER_MANAGER) == false) {
            revert AddressMustImplementITransferManager();
        }
        treasury = _treasury;
        transferManager = _transferManager;
        trustedWallet = _trustedWallet;
        __Ownable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    // External functions

    function setTreasury(address payable _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }

    function setTransferManager(address _transferManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_transferManager == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        if (ITransferManager(_transferManager).supportsInterface(_INTERFACE_ID_TRANSFER_MANAGER) == false) {
            revert AddressMustImplementITransferManager();
        }
        transferManager = _transferManager;
        emit TransferManagerChanged(_transferManager);
    }

    function setTrustedWallet(address _trustedWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_trustedWallet == address(0)) {
            revert AddressCannotBeAddressZero();
        }
        trustedWallet = _trustedWallet;
        emit TrustedWalletChanged(_trustedWallet);
    }

    function checkout_J2u(Order[] memory requests, bytes[] memory signature) external payable nonReentrant {
        if (requests.length != signature.length) {
            revert NumberOfArgumentsIsInvalidInCheckoutContext();
        }
        uint256 totalETHAmount;
        for (uint256 i = 0; i < requests.length; ++i) {
            checkSignature(requests[i], signature[i]);
            if (requests[i].currency == address(0)) {
                totalETHAmount = totalETHAmount.add(requests[i].amount);
            } else {
                if (requests[i].mintErc20Amount != 0) {
                    ITransferManager(transferManager).mintERC20(
                        requests[i].currency,
                        requests[i].receiver,
                        requests[i].mintErc20Amount
                    );
                }
                ITransferManager(transferManager).transferFromERC20(
                    requests[i].currency,
                    requests[i].receiver,
                    transferManager,
                    requests[i].amount
                );
            }

            _makeTransfer(requests[i]);
        }
        if (msg.value != totalETHAmount) {
            revert InvalidAmount();
        }
    }

    function crypto_n13(Order memory request, bytes memory signature) external payable nonReentrant {
        checkSignature(request, signature);
        if (msg.value != request.amount) {
            revert InvalidAmount();
        }
        request.currency = address(0);
        _makeTransfer(request);
    }

    function token_4op(Order memory request, bytes memory signature) external nonReentrant {
        checkSignature(request, signature);
        if (request.mintErc20Amount != 0) {
            ITransferManager(transferManager).mintERC20(request.currency, request.receiver, request.mintErc20Amount);
        }
        ITransferManager(transferManager).transferFromERC20(
            request.currency,
            request.receiver,
            transferManager,
            request.amount
        );
        _makeTransfer(request);
    }

    // Public functions

    function createOrderHash_jfO(Order memory request) public view returns (bytes32) {
      bytes memory encondePartial = abi.encodePacked(
          request.tokenId,
          request.amount,
          request.fee,
          request.nftContract,
          request.receiver,
          request.currency,
          request.owner,
          request.payees,
          request.shares,
          request.signatureExpiresAt,
          request.mintErc20Amount,
          request.payRoyalty,
          request.externalId
        );
        return keccak256(
            abi.encodePacked(
                encondePartial,
                address(this),
                block.chainid
            )
        );
    }

    // Private functions

    function _makeTransfer(Order memory request) private {
        if (request.payees.length != request.shares.length || request.payees.length == 0) {
            revert InvalidShares();
        }

        uint256 royaltyFeeAmount;
        uint256 amountPaid;
        uint256 totalShares;
        uint256 marketFee = _payMarket(request.amount, request.fee, request.currency);
        uint256 remainderAmount = request.amount.sub(marketFee);

        if (request.payRoyalty && request.nftContract != address(0)) {
            (, royaltyFeeAmount) = _payRoyalty(request.nftContract, request.tokenId, remainderAmount, request.currency);
            remainderAmount = remainderAmount.sub(royaltyFeeAmount);
        }

        for (uint8 i = 0; i < request.payees.length; ++i) {
            totalShares = totalShares.add(request.shares[i]);
        }

        // in this case it will only have an IF cost
        if (request.currency == address(0)) {
            for (uint8 i = 0; i < request.payees.length; ++i) {
                uint256 amountPending = remainderAmount.mul(request.shares[i]).div(totalShares);
                amountPaid = amountPaid.add(amountPending);
                _sendValueWithFallbackWithdrawWithMediumGasLimit(payable(request.payees[i]), amountPending);
            }
        } else {
            for (uint8 i = 0; i < request.payees.length; ++i) {
                uint256 amountPending = remainderAmount.mul(request.shares[i]).div(totalShares);
                amountPaid = amountPaid.add(amountPending);
                ITransferManager(transferManager).transferERC20(request.currency, request.payees[i], amountPending);
            }
        }

        if (
            (remainderAmount != amountPaid) || (remainderAmount.add(royaltyFeeAmount).add(marketFee) != request.amount)
        ) {
            revert RatesAreIncompatible();
        }

        if (request.nftContract != address(0)) {
            if (request.tokenId == 0) {
                uint256 balanceOfBeforeMint = IERC721Upgradeable(request.nftContract).balanceOf(request.receiver);
                ITransferManager(transferManager).mintERC721A(request.nftContract, request.receiver, 1);
                uint256 balanceOfAfterMint = IERC721Upgradeable(request.nftContract).balanceOf(request.receiver);
                if (balanceOfAfterMint <= balanceOfBeforeMint) {
                    revert MintFailed();
                }
            } else {
                ITransferManager(transferManager).transferFromERC721(
                    request.nftContract,
                    request.owner,
                    request.receiver,
                    request.tokenId
                );
            }
        }

        emit WeblockNftTransfered(
            request.nftContract,
            request.tokenId,
            request.owner,
            request.receiver,
            request.amount
        );


        externalIdsAlreadyUsed[request.externalId] = true;
    }

    function _payMarket(uint256 amount, uint256 fee, address currency) private returns (uint256 marketFee) {
        if (fee == 0) {
            return 0;
        }

        marketFee = amount.mul(fee) / _BASIS_POINTS_PER_PERCENTAGE;
        if (currency == address(0)) {
            _deposit(treasury, marketFee);
        } else {
            ITransferManager(transferManager).transferERC20(currency, treasury, marketFee);
        }
    }

    function _getRoyaltyInfo(
        address nftContract,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (address receiver, uint256 royaltyAmount) {
        if (IERC165Upgradeable(nftContract).supportsInterface(_INTERFACE_ID_ERC2981)) {
            (receiver, royaltyAmount) = IERC2981Upgradeable(nftContract).royaltyInfo(tokenId, amount);
        }
        return (receiver, royaltyAmount);
    }

    function _payRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address currency
    ) private returns (address royaltyFeeRecipient, uint256 royaltyFeeAmount) {
        (royaltyFeeRecipient, royaltyFeeAmount) = _getRoyaltyInfo(nftContract, tokenId, amount);
        if (royaltyFeeRecipient == address(0) || royaltyFeeAmount == 0) {
            return (address(0), 0);
        }
        if (currency == address(0)) {
            _sendValueWithFallbackWithdrawWithMediumGasLimit(payable(royaltyFeeRecipient), royaltyFeeAmount);
        } else {
            ITransferManager(transferManager).transferERC20(currency, royaltyFeeRecipient, royaltyFeeAmount);
        }
        emit RoyaltyPayment(nftContract, tokenId, royaltyFeeRecipient, royaltyFeeAmount);
    }

    function getSignedMessageHash(bytes32 _messageHash) private pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function checkSignature(Order memory request, bytes memory signature) private view {
        if (request.signatureExpiresAt < block.timestamp) {
            revert SignatureExpired();
        }

        bytes32 messageHash = createOrderHash_jfO(request);
        bytes32 signedMessageHash = getSignedMessageHash(messageHash);

        if (recoverSigner(signedMessageHash, signature) != trustedWallet) {
            revert InvalidSignature();
        }

        if (externalIdsAlreadyUsed[request.externalId]) {
          revert ExternalIdAlreadyUsed();
        }
    }

    function recoverSigner(bytes32 _signedMessageHash, bytes memory _signature) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_signedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}
