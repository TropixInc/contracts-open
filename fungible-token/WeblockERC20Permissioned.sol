// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./WeblockFungibleToken.sol";

contract WeblockERC20Permissioned is Initializable, WeblockFungibleToken {
    bytes32 public constant MOVER_ROLE = keccak256("MOVER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
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
        _grantRole(MOVER_ROLE, owner);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (hasRole(MOVER_ROLE, _msgSender())) {
            _approve(from, _msgSender(), amount);
        }
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }
}
