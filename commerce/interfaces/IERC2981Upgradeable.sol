// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/// @notice This is purely an extension for the Tropix platform
/// @notice Royalties on Tropix are defined at an edition level for all tokens from the same edition
interface IERC2981EditionExtensionUpgradeable {
  /// @notice Does the edition have any royalties defined
  function hasRoyalties(uint256 _editionId) external view returns (bool);

  /// @notice Get the royalty receiver - all royalties should be sent to this account if not zero address
  function getRoyaltiesReceiver(uint256 _editionId) external view returns (address);

  /// @notice Get the royalty amount - all royalties should be sent to this account if not zero address
  function getRoyaltiesAmount(uint256 _editionId) external view returns (uint256);
}

/**
 * ERC2981 standards interface for royalties
 */
interface IERC2981Upgradeable is IERC165Upgradeable, IERC2981EditionExtensionUpgradeable {
  /// ERC165 bytes to add to interface array - set in parent contract
  /// implementing this standard
  ///
  /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
  /// bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  /// _registerInterface(_INTERFACE_ID_ERC2981);

  /// @notice Called with the sale price to determine how much royalty
  //          is owed and to whom.
  /// @param _tokenId - the NFT asset queried for royalty information
  /// @param _value - the sale price of the NFT asset specified by _tokenId
  /// @return _receiver - address of who should be sent the royalty payment
  /// @return _royaltyAmount - the royalty payment amount for _value sale price
  function royaltyInfo(uint256 _tokenId, uint256 _value)
    external
    view
    returns (address _receiver, uint256 _royaltyAmount);
}
