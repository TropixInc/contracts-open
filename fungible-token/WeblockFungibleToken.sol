// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract WeblockFungibleToken is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    bool public isBurnable;

    uint224 public maxSupply;

    event BurnableChanged(bool isBurnable);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function __WeblockFungibleToken_init(
        string memory _name,
        string memory _symbol,
        address _initialOwner,
        uint256 _initialAmount,
        bool _isBurnable,
        uint224 _maxSupply,
        address owner
    ) internal onlyInitializing {
        __ERC20_init(_name, _symbol);
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init(_name);
        __Ownable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(BURNER_ROLE, owner);
        transferOwnership(owner);

        if (_initialOwner != address(0)) {
            _mint(_initialOwner, _initialAmount);
        }

        isBurnable = _isBurnable;

        maxSupply = _maxSupply == 0 ? type(uint224).max : _maxSupply;
    }

    function setBurnable(bool _isBurnable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isBurnable = _isBurnable;
        emit BurnableChanged(_isBurnable);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= maxSupply, "WeblockFungibleToken: max supply exceeded");
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        require(isBurnable, "WeblockFungibleToken: burnable is not enabled");
        if (hasRole(BURNER_ROLE, _msgSender())) {
            _approve(account, _msgSender(), amount);
        }
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function burn(uint256 amount) external {
        require(isBurnable, "WeblockFungibleToken: burnable is not enabled");
        _burn(_msgSender(), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
