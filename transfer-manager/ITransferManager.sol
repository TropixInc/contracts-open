// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface ITransferManager is IERC165Upgradeable {
    /**
     * @notice Transfer ERC721 token
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId of the token
     */
    function transferFromERC721(address collection, address from, address to, uint256 tokenId) external payable;

    /**
     * @notice Transfer ERC1155 token(s)
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     * @param amount amount of tokens (1 and more for ERC1155)
     */
    function transferFromERC1155(
        address collection,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external payable;

    /**
      @notice Transfer ERC20 token
      @param currency address of the currency
      @param from address of the sender
      @param to address of the recipient
      @param amount amount of tokens
     */
    function transferFromERC20(address currency, address from, address to, uint256 amount) external payable returns (bool);

    /**
      * @notice Transfer ERC20 token
      * @param currency address of the currency
      * @param to address of the recipient
      * @param amount amount of tokens
      
     */
    function transferERC20(address currency, address to, uint256 amount) external payable returns (bool);

    /**
     * @notice has allowance to transfer ERC20 token
     * @param currency address of the currency
     * @param from address of the sender
     * @param to address of the recipient
     * @param amount amount of tokens
     */
    function hasAllowance(address currency, address from, address to, uint256 amount) external view returns (bool);

    /**
     * @notice Mint ERC721A token
     * @param collection address of the collection
     * @param owner address of the owner
     * @param quantity quantity of tokens
     */
    function mintERC721A(address collection, address owner, uint256 quantity) external payable;

    /**
     * @notice Mint ERC20 token
     * @param currency address of the contract
     * @param owner address of the owner
     * @param quantity quantity of tokens
     */
    function mintERC20(address currency, address owner, uint256 quantity) external;
}
