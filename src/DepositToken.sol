// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/// @title A ERC20 based Deposit Token SC
/// @author abhi3700
/// @notice A ERC20 Token
/// @dev A ERC20 based Deposit Token SC
contract DepositToken is ERC20, Ownable, Pausable {
    // ==========State variables====================================

    // ==========Events=============================================
    event TokenMinted(address indexed toAcct, uint256 amount);
    event TokenBurnt(address indexed fromAcct, uint256 amount);

    // ==========Constructor========================================
    constructor(string memory _n, string memory _s, uint256 _initialSupply) ERC20(_n, _s) Ownable() {
        _mint(_msgSender(), _initialSupply);
    }

    // ==========Functions==========================================
    function mint(address _account, uint256 _amount) external onlyOwner whenNotPaused returns (bool) {
        require(_amount > 0, "amount must be positive");
        _mint(_account, _amount);

        emit TokenMinted(_account, _amount);

        return true;
    }

    function burn(uint256 _amount) external whenNotPaused returns (bool) {
        require(_amount > 0, "amount must be positive");
        _burn(_msgSender(), _amount);

        emit TokenBurnt(_msgSender(), _amount);

        return true;
    }

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
