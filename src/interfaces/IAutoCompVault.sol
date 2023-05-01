// SPDX-License-Identifier: MIT
pragma solidity version ^0.8.0;

interface IAutoCompVault {
    /// @dev Returns the amount of deposit token for a given user address
    function depositOf(address _account) public view returns (uint256);

    /// @dev Returns the total amount of shares for all users
    function totalShares() public view returns (uint256);

    /// @dev Returns the amount of shares for a given user address
    function sharesOf(address _account) public view returns (uint256);

    /// @dev get the PPFS (price per full share)
    function getPPFS() public view returns (uint256);

    /// @dev Deposit tokens to the vault
    function deposit(IERC20 _depositToken, uint256 _amount) external;

    /// @dev Redeem tokens (including autocompound) from the vault
    function redeem(uint256 _shareAmount) external;

    /// @notice Pause contract
    function pause() public;
    
    /// @notice Unpause contract
    function unpause() public
}
