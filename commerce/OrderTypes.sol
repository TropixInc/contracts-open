// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library OrderTypes {
    struct Order {
        address nftContract; // collection address
        uint256[] tokensIds; // tokensIds for sale
        uint256 amount; // price of each tokenId in gwei (native currency)
        address payee; // address to send funds to
        uint256 fee;
        bool payRoyalty;
        uint256 expirationTime; // when order expires
        address[] erc20Addresses; // currencies to accept
        uint256[] erc20Amounts; // amount of each currency to accept
    }
}
