// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IWeblockFungibleToken is IERC20Upgradeable {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function burn(uint256 amount) external;
}
