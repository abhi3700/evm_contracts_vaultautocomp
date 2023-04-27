// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // CRVstETH token (deposit/invest token)
    IERC20 public depositToken;

    // receipt token - RCRVstETH (shares)
    ERC20 public receiptToken;

    struct Investment {
        uint256 depositedAmt;
        uint256 sharesAmt;
    }

    mapping(address => Investment) public vaults;

    uint256 public totalDeposited;

    uint256 public immutable dailyield;

    // Errors
    error ZeroAddress();
    error ZeroAmount();
    error ZeroYield();
    error InvalidToken();

    constructor(address _token, uint256 _dailyield) {
        if (_token == address(0)) {
            revert ZeroAddress();
        }

        if (_dailyield == 0) {
            revert ZeroYield();
        }

        dailyield = _dailyield;

        depositToken = IERC20(_token);

        // create a receipt token whose owner is `address(this)`
        receiptToken = new ERC20("Receipt Token", "RCRVstETH");
    }

    // ======Getters======

    /// @dev Returns the total amount of shares for all users
    function totalShares() public view returns (uint256) {
        return receiptToken.totalSupply();
    }

    /// @dev Returns the amount of shares for a given user address
    function sharesOf(address _account) public view returns (uint256) {
        return receiptToken.balanceOf(_account);
    }

    /// @dev Returns the amount of deposit token for a given user address
    function depositedOf(address _account) public view returns (uint256) {
        return vaults[_account].depositedAmt;
    }

    // ======Setters======

    /// @dev Deposit tokens to the vault
    function deposit(IERC20 _depositToken, uint256 _amount) external nonReentrant whenNotPaused {
        if (_depositToken != depositToken) {
            revert InvalidToken();
        }

        if (_amount == 0) {
            revert ZeroAmount();
        }

        // calculate receipt token amount

        // transferFrom deposit token to vault

        // mint receipt token to msg.sender
    }

    function withdraw(uint256 _amount) external nonReentrant whenNotPaused {}

    // ------------------------------------------------------------------------------------------
    /// @notice Pause contract
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
