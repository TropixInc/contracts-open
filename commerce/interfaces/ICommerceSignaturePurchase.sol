// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {OrderTypes} from "../OrderTypes.sol";

interface ICommerceSignaturePurchase {
    error InvalidSignature();
    error SignatureExpired();
    error TrustWalletCannotBeAddressZero();

    event NewTrustedWallet(address trustedWallet);

    function setTrustedWallet(address _trustedWallet) external;

    function getSignedMessageHash(bytes32 _messageHash) external pure returns (bytes32);

    function recoverSigner(bytes32 _signedMessageHash, bytes memory _signature) external pure returns (address);

    function splitSignature(bytes memory sig)
        external
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        );

    function checkSignature(
        bytes32 messageHash,
        bytes memory signature,
        uint256 signatureExpiresAt
    ) external view;

    function createOrderHash(OrderTypes.Order memory request, uint256 signatureExpiresAt)
        external
        pure
        returns (bytes32);

    function createUpdateOrderTokensHash(
        uint256 orderId,
        uint256[] calldata tokensIds,
        address requester,
        uint256 signatureExpiresAt
    ) external pure returns (bytes32);

    function createOrderIdHash(
        uint256 orderId,
        address requester,
        uint256 signatureExpiresAt
    ) external pure returns (bytes32);

    function createUpdateOrderCurrencyHash(
        uint256 orderId,
        uint256 amount,
        address[] calldata erc20Addresses,
        uint256[] calldata erc20Amounts,
        address requester,
        uint256 signatureExpiresAt
    ) external pure returns (bytes32);

    function createUpdateOrderExpirationTimeHash(
        uint256 orderId,
        uint256 expirationTimeExtension,
        address requester,
        uint256 signatureExpiresAt
    ) external pure returns (bytes32);

    function createBuyHash(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        uint256 amount,
        uint256 signatureExpiresAt
    ) external pure returns (bytes32);

    function createBuyWithCurrencyHash(
        uint256 orderId,
        uint256 tokenId,
        address receiver,
        address currency,
        uint256 amount,
        uint256 signatureExpiresAt
    ) external pure returns (bytes32);
}
