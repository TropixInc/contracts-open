// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./WeblockFungibleToken.sol";

contract WeblockERC20 is Initializable, WeblockFungibleToken {
    constructor() {}

    function initialize(
        string memory _name,
        string memory _symbol,
        address _initialOwner,
        uint256 _initialAmount,
        bool _isBurnable,
        uint224 _maxSupply,
        address owner
    ) public initializer {
        __WeblockFungibleToken_init(_name, _symbol, _initialOwner, _initialAmount, _isBurnable, _maxSupply, owner);
    }
}
