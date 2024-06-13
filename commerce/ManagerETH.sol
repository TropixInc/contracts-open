// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract ManagerETH is ContextUpgradeable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address payable;
    using SafeMathUpgradeable for uint256;
    event WithdrawPending(address indexed payee, uint256 amount);

    event Withdrawal(address indexed payee, uint256 amount);

    error NoFoundArePendingWithdrawal();

    mapping(address => uint256) private _pendingWithdrawals;

    /**
     * @dev Attempt to send a payee or contract ETH with a moderate gas limit of 90k,
     * which is enough for a 5-way split.
     */
    function _sendValueWithFallbackWithdrawWithMediumGasLimit(address payable payee, uint256 amount) internal {
        _sendValueWithFallbackWithdraw(payee, amount, 210000);
    }

    /**
     * @dev Attempt to send a payee or contract ETH and if it fails store the amount owned for later withdrawal.
     */
    function _sendValueWithFallbackWithdraw(
        address payable payee,
        uint256 amount,
        uint256 gasLimit
    ) private {
        if (amount == 0) {
            return;
        }
        // Cap the gas to prevent consuming all available gas to block a tx from completing successfully
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = payee.call{value: amount, gas: gasLimit}("");
        if (!success) {
            // Record failed sends for a withdrawal later
            // Transfers could fail if sent to a multisig with non-trivial receiver logic
            // solhint-disable-next-line reentrancy
            _deposit(payee, amount);
        }
    }

    /**
     * @dev Stores the sent amount as credit to be withdrawn.
     * @param payee The destination address of the funds.
     */
    function _deposit(address payee, uint256 amount) internal {
        _pendingWithdrawals[payee] = _pendingWithdrawals[payee].add(amount);
        emit WithdrawPending(payee, amount);
    }

    /**
     * @dev Withdraw accumulated payments, forwarding all gas to the recipient.
     *
     * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
     * Make sure you trust the recipient, or are either following the
     * checks-effects-interactions pattern or using {ReentrancyGuard}.
     *
     * @param payee Whose payments will be withdrawn.
     */
    function _withdraw(address payable payee) internal {
        uint256 amount = _pendingWithdrawals[payee];
        if (amount == 0) {
            revert NoFoundArePendingWithdrawal();
        }
        _pendingWithdrawals[payee] = 0;
        payee.sendValue(amount);
        emit Withdrawal(payee, amount);
    }

    /**
     * @notice Allows a payee to manually withdraw funds which originally failed to transfer to themselves.
     */
    function withdraw() public nonReentrant {
        _withdraw(payable(_msgSender()));
    }

    /**
     * @notice Allows anyone to manually trigger a withdrawal of funds which originally failed to transfer for a user.
     * @param payee Whose payments will be withdrawn.
     */
    function withdraw(address payable payee) public nonReentrant {
        _withdraw(payee);
    }

    // Escrow

    function escrowOf(address payee) public view returns (uint256) {
        return _pendingWithdrawals[payee];
    }
}
