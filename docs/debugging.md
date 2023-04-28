# Debugging

- Remember there is a mandatory `setUp` call before each function call.
- Used `msg.sender` using `console.log` to check the caller as in **foundry**, we don't have the option of adding caller during the function call as we do in **hardhat**. Here, need to use the `vm.prank` (for next function call), `vm.startPrank(alice)` (for all the next function calls) and `vm.stopPrank()` (to stop the prank, used at the end of all calls) to set the original caller back.
- Also had to fix the arithmetic operations (priority rule) commented in the code as it was not working as expected.
- During `receiptAmt` calculation, tried with `num/denom` approach, but failed. Code that failed is:

```solidity
uint256 numerator = _amount * 1e18 * yieldDuration * scalingFactor * totalShares();
uint256 denominator = _totalDeposited * 1e18
    * (yieldDuration * scalingFactor + (block.timestamp - lastDepositedTimestamp) * yieldPercentage);
uint256 receiptAmt = numerator / denominator;
```

> LESSON: `x + y/z` can't be treated as `(z+y)/z`. We need to choose b/w multiplication (1st) vs division (2nd). Don't complicate with '+', '-'.

- dfs
