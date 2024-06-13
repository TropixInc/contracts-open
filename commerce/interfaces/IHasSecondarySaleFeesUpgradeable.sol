// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/// @title Royalties formats required for use on the Rarible platform
/// @dev https://docs.rarible.org/ethereum/smart-contracts/royalties/
interface IHasSecondarySaleFeesUpgradeable is IERC165Upgradeable {
  event SecondarySaleFees(uint256 tokenId, address[] recipients, uint256[] bps);

  function getFeeRecipients(uint256 id) external returns (address payable[] memory);

  function getFeeBps(uint256 id) external returns (uint256[] memory);
}
