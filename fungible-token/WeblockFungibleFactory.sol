// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./WeblockERC20.sol";
import "./WeblockERC20Permissioned.sol";
import "./WeblockERC20InCustody.sol";

contract WeblockFungibleFactory is OwnableUpgradeable {
    using ClonesUpgradeable for address;

    struct FungibleTokenArgs {
        string name;
        string symbol;
        string uuid;
        address initialOwner;
        uint256 initialAmount;
        uint224 maxSupply;
        bool isBurnable;
    }

    address public erc20;
    address public erc20Permissioned;
    address public erc20InCustody;

    event DeployERC20(address indexed addressERC20);
    event DeployERC20Permissioned(address indexed addressERC20Permissioned);
    event DeployERC20InCustody(address indexed addressERC20Custody);

    function initialize(address _erc20, address _erc20Permissioned, address _erc20InCustody) public initializer {
        require(_erc20 != address(0), "ERC20 address is invalid");
        require(_erc20Permissioned != address(0), "ERC20 Permissioned address is invalid");
        erc20 = _erc20;
        erc20Permissioned = _erc20Permissioned;
        erc20InCustody = _erc20InCustody;
    }

    function getERC20Address(bytes32 salt) public view returns (address) {
        require(erc20 != address(0), "ERC20 must be set");
        return erc20.predictDeterministicAddress(salt);
    }

    function getERC20PermissionedAddress(bytes32 salt) public view returns (address) {
        require(erc20Permissioned != address(0), "ERC20 Permissioned must be set");
        return erc20Permissioned.predictDeterministicAddress(salt);
    }

    function getERC20InCustodyAddress(bytes32 salt) public view returns (address) {
        require(erc20Permissioned != address(0), "ERC20 In Custody must be set");
        return erc20InCustody.predictDeterministicAddress(salt);
    }

    function setERC20Address(address _erc20) external onlyOwner {
        require(_erc20 != address(0), "ERC20 must be set");
        erc20 = _erc20;
    }

    function setERC20PermissionedAddress(address _erc20Permissioned) external onlyOwner {
        require(_erc20Permissioned != address(0), "ERC20 Permissioned must be set");
        erc20Permissioned = _erc20Permissioned;
    }

    function getSalt(string memory uuid) public pure returns (bytes32) {
        require(bytes(uuid).length > 0, "UUID required");
        return keccak256(abi.encodePacked(uuid));
    }

    function deployERC20(FungibleTokenArgs memory args) external {
        bytes32 salt = getSalt(args.uuid);
        cloneERC20(salt);
        address addressERC20 = getERC20Address(salt);
        WeblockERC20(addressERC20).initialize(
            args.name,
            args.symbol,
            args.initialOwner,
            args.initialAmount,
            args.isBurnable,
            args.maxSupply,
            msg.sender
        );
        emit DeployERC20(addressERC20);
    }

    function deployERC20Permissioned(FungibleTokenArgs memory args) external {
        bytes32 salt = getSalt(args.uuid);
        cloneERC20Permissioned(salt);
        address addressERC20Permissioned = getERC20PermissionedAddress(salt);
        WeblockERC20Permissioned(addressERC20Permissioned).initialize(
            args.name,
            args.symbol,
            args.initialOwner,
            args.initialAmount,
            args.isBurnable,
            args.maxSupply,
            msg.sender
        );
        emit DeployERC20Permissioned(addressERC20Permissioned);
    }

    function deployERC20InCustody(FungibleTokenArgs memory args) external {
        bytes32 salt = getSalt(args.uuid);
        cloneERC20InCustody(salt);
        address addressERC20InCustody = getERC20InCustodyAddress(salt);
        WeblockERC20InCustody(addressERC20InCustody).initialize(
            args.name,
            args.symbol,
            args.initialOwner,
            args.initialAmount,
            args.isBurnable,
            args.maxSupply,
            msg.sender
        );
        emit DeployERC20InCustody(addressERC20InCustody);
    }

    function cloneERC20(bytes32 salt) internal {
        erc20.cloneDeterministic(salt);
    }

    function cloneERC20Permissioned(bytes32 salt) internal {
        erc20Permissioned.cloneDeterministic(salt);
    }

    function cloneERC20InCustody(bytes32 salt) internal {
        erc20InCustody.cloneDeterministic(salt);
    }
}
