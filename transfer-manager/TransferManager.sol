// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IWeblockFungibleToken} from "../fungible-token/IWeblockFungibleToken.sol";
import {ITransferManager, IERC165Upgradeable} from "./ITransferManager.sol";
import {IPixwayERC721A} from "../IPixwayERC721A.sol";

contract TransferManager is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    ITransferManager
{
    function initialize() public initializer {
        __Ownable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Transfer ERC721 token
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId of the token
     */
    function transferFromERC721(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) external payable override onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721Upgradeable(collection).transferFrom(from, to, tokenId);
    }

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
    ) external payable override onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC1155Upgradeable(collection).safeTransferFrom(from, to, tokenId, amount, "");
    }

    /**
      @notice Transfer ERC20 token
      @param currency address of the currency
      @param from address of the sender
      @param to address of the recipient
      @param amount amount of tokens
     */
    function transferFromERC20(
        address currency,
        address from,
        address to,
        uint256 amount
    ) public payable override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return IWeblockFungibleToken(currency).transferFrom(from, to, amount);
    }

    /**
      * @notice Transfer ERC20 token
      * @param currency address of the currency
      * @param to address of the recipient
      * @param amount amount of tokens
      
     */
    function transferERC20(
        address currency,
        address to,
        uint256 amount
    ) public payable override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        if (IWeblockFungibleToken(currency).transfer(to, amount)) {
            return true;
        }
        return transferFromERC20(currency, address(this), to, amount);
    }

    /**
     * @notice has allowance to transfer ERC20 token
     * @param currency address of the currency
     * @param from address of the sender
     * @param to address of the recipient
     * @param amount amount of tokens
     */
    function hasAllowance(address currency, address from, address to, uint256 amount) external view returns (bool) {
        return IWeblockFungibleToken(currency).allowance(from, to) >= amount;
    }

    /**
     * @notice Mint ERC721A token
     * @param collection address of the collection
     * @param owner address of the owner
     * @param quantity quantity of tokens
     */
    function mintERC721A(
        address collection,
        address owner,
        uint256 quantity
    ) external payable override onlyRole(DEFAULT_ADMIN_ROLE) {
        IPixwayERC721A(collection).mint(owner, quantity);
    }

     /**
     * @notice Mint ERC20 token
     * @param currency address of the contract
     * @param owner address of the owner
     * @param quantity quantity of tokens
     */
    function mintERC20(
        address currency,
        address owner,
        uint256 quantity
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        IWeblockFungibleToken(currency).mint(owner, quantity);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControlUpgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == bytes4(keccak256("transferFromERC721(address,address,address,uint256)")) ||
            interfaceId == bytes4(keccak256("transferFromERC1155(address,address,address,uint256,uint256)")) ||
            interfaceId == bytes4(keccak256("transferFromERC20(address,address,address,uint256)")) ||
            interfaceId == bytes4(keccak256("mintERC721A(address,address,uint256)")) ||
            interfaceId == bytes4(keccak256("mintERC20(address,address,uint256)")) ||
            super.supportsInterface(interfaceId);
    }
}
