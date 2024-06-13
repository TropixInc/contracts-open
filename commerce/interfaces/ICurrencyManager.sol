// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICurrencyManager {
    error CurrencyAlreadyWhitelisted(address currency);
    error CurrencyNotWhitelisted(address currency);

    event CurrencyRemoved(address indexed currency);
    event CurrencyAdded(address indexed currency);

    function addCurrency(address currency) external;

    function removeCurrency(address currency) external;

    function isCurrencyWhitelisted(address currency) external view returns (bool);

    function getSize() external view returns (uint256);

    function getCurrencies(uint256 cursor, uint256 size)
        external
        view
        returns (address[] memory currencies, uint256 endCursor);
}
