// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EnumerableSetUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import {ICurrencyManager} from "./interfaces/ICurrencyManager.sol";

contract CurrencyManager is ICurrencyManager, Initializable, ContextUpgradeable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet private _whitelistedCurrencies;

    function initialize() public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Add a currency in the system
     * @param currency address of the currency to add
     */
    function addCurrency(address currency) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_whitelistedCurrencies.contains(currency)) {
            revert CurrencyAlreadyWhitelisted(currency);
        }
        _whitelistedCurrencies.add(currency);

        emit CurrencyAdded(currency);
    }

    /**
     * @notice Remove a currency from the system
     * @param currency address of the currency to remove
     */
    function removeCurrency(address currency) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_whitelistedCurrencies.contains(currency)) {
            revert CurrencyNotWhitelisted(currency);
        }
        _whitelistedCurrencies.remove(currency);

        emit CurrencyRemoved(currency);
    }

    /**
     * @notice Returns if a currency is in the system
     * @param currency address of the currency
     */
    function isCurrencyWhitelisted(address currency) external view override returns (bool) {
        return _whitelistedCurrencies.contains(currency);
    }

    /**
     * @notice View number of whitelisted currencies
     */
    function getSize() external view override returns (uint256) {
        return _whitelistedCurrencies.length();
    }

    /**
     * @notice See whitelisted currencies in the system
     * @param cursor cursor (should start at 0 for first request)
     * @param size size of the response (e.g., 50)
     */
    function getCurrencies(uint256 cursor, uint256 size)
        external
        view
        override
        returns (address[] memory currencies, uint256 endCursor)
    {
        uint256 length = size;

        if (length > _whitelistedCurrencies.length() - cursor) {
            length = _whitelistedCurrencies.length() - cursor;
        }

        address[] memory whitelistedCurrencies = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            whitelistedCurrencies[i] = _whitelistedCurrencies.at(cursor + i);
        }

        return (whitelistedCurrencies, cursor + length);
    }
}
