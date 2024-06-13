// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {ICommerceSignaturePurchase} from "./interfaces/ICommerceSignaturePurchase.sol";

import {OrderTypes} from "./OrderTypes.sol";

contract CommerceSignaturePurchase is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ICommerceSignaturePurchase
{
    using OrderTypes for OrderTypes.Order;

    address public trustedWallet;

    function initialize(address _trustedWallet) public initializer {
        if (_trustedWallet == address(0)) {
            revert TrustWalletCannotBeAddressZero();
        }
        trustedWallet = _trustedWallet;

        __Ownable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setTrustedWallet(address _trustedWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_trustedWallet == address(0)) {
            revert TrustWalletCannotBeAddressZero();
        }
        trustedWallet = _trustedWallet;
        emit NewTrustedWallet(_trustedWallet);
    }

    function getSignedMessageHash(bytes32 _messageHash) public pure override returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function recoverSigner(bytes32 _signedMessageHash, bytes memory _signature) public pure override returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_signedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
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

    // Signature

    function checkSignature(
        bytes32 messageHash,
        bytes memory signature,
        uint256 signatureExpiresAt
    ) public view override {
        bytes32 signedMessageHash = getSignedMessageHash(messageHash);

        if (recoverSigner(signedMessageHash, signature) != trustedWallet) {
            revert InvalidSignature();
        }
        if (signatureExpiresAt < block.timestamp) {
            revert SignatureExpired();
        }
    }

    function createOrderHash(OrderTypes.Order memory request, uint256 signatureExpiresAt)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    request.nftContract,
                    request.tokensIds,
                    request.amount,
                    request.payee,
                    request.fee,
                    request.payRoyalty,
                    request.expirationTime,
                    request.erc20Addresses,
                    request.erc20Amounts,
                    signatureExpiresAt
                )
            );
    }

    function createUpdateOrderTokensHash(
        uint256 orderId,
        uint256[] calldata tokensIds,
        address requester,
        uint256 signatureExpiresAt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(orderId, tokensIds, requester, signatureExpiresAt));
    }

    function createOrderIdHash(
        uint256 orderId,
        address requester,
        uint256 signatureExpiresAt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(orderId, requester, signatureExpiresAt));
    }

    function createUpdateOrderCurrencyHash(
        uint256 orderId,
        uint256 amount,
        address[] calldata erc20Addresses,
        uint256[] calldata erc20Amounts,
        address requester,
        uint256 signatureExpiresAt
    ) public pure override returns (bytes32) {
        return
            keccak256(abi.encodePacked(orderId, amount, erc20Addresses, erc20Amounts, requester, signatureExpiresAt));
    }

    function createUpdateOrderExpirationTimeHash(
        uint256 orderId,
        uint256 expirationTimeExtension,
        address requester,
        uint256 signatureExpiresAt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(orderId, expirationTimeExtension, requester, signatureExpiresAt));
    }

    function createBuyHash(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        uint256 amount,
        uint256 signatureExpiresAt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(orderId, tokenId, receiver, amount, signatureExpiresAt));
    }

    function createBuyWithCurrencyHash(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        address currency,
        uint256 amount,
        uint256 signatureExpiresAt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(orderId, tokenId, receiver, currency, amount, signatureExpiresAt));
    }
}
