// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IWeblockNftMarketplace {
    struct Order {
        uint256 tokenId;
        uint256 amount;
        uint256 mintErc20Amount;
        uint256 fee;
        uint256 signatureExpiresAt;
        address nftContract;
        address receiver;
        address currency;
        address owner;
        bool payRoyalty;
        address[] payees;
        uint256[] shares;
        uint32 externalId;
    }

    error InvalidAmount();

    error InvalidSignature();

    error SignatureExpired();

    error AddressCannotBeAddressZero();

    error AddressMustImplementITransferManager();

    error InvalidShares();

    error RatesAreIncompatible();

    error NumberOfArgumentsIsInvalidInCheckoutContext();

    error MintFailed();

    event WeblockNftTransfered(
        address indexed nftContract,
        uint256 indexed tokenId,
        address from,
        address to,
        uint256 amount
    );

    event RoyaltyPayment(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed royaltyRecipient,
        uint256 amount
    );

    event TreasuryChanged(address treasury);

    event TransferManagerChanged(address transferManager);

    event TrustedWalletChanged(address transferManager);

    error ExternalIdAlreadyUsed();


}
