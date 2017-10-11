# Aragon-Payroll-Contract

## Introduction

With respect to accepting the challenge given from Aragon https://github.com/aragon/jobs/blob/master/openings/solidity.md:

Interface given to start the challenge:

```

// For the sake of simplicity lets assume USD is a ERC20 token
// Also lets assume we can 100% trust the exchange rate oracle
contract PayrollInterface {
  /* OWNER ONLY */
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary);
  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary);
  function removeEmployee(uint256 employeeId);

  function addFunds() payable;
  function scapeHatch();
  // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

  function getEmployeeCount() constant returns (uint256);
  function getEmployee(uint256 employeeId) constant returns (address employee); // Return all important info too

  function calculatePayrollBurnrate() constant returns (uint256); // Monthly usd amount spent in salaries
  function calculatePayrollRunway() constant returns (uint256); // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution); // only callable once every 6 months
  function payday(); // only callable once a month

  /* ORACLE ONLY */
  function setExchangeRate(address token, uint256 usdExchangeRate); // uses decimals from token
}

```

However I've changes the interface to the below:

```
pragma solidity ^0.4.17;

contract PayrollInterface {
  /* OWNER ONLY */
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) public returns(uint256 employeeId);
  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public;
  function removeEmployee(uint256 employeeId) public;

  function escapeHatch() public;
  function backToBusiness() public;
  
  function addFunds() payable public returns(string);
  function tokenFallback() public;

  function getEmployeeCount() public constant returns (uint256);
  function getEmployee(uint256 employeeId) public constant returns (address accountAddress, address[] allowedTokens, uint256 yearlyUSDSalary, uint lastPayDay); // Return all important info too

  function calculatePayrollBurnrate() public constant returns (uint256); // Monthly usd amount spent in salaries
  function calculatePayrollRunway() public constant returns (uint256); // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution) public; // only callable once every 6 months
  function payday() public; // only callable once a month

  /* ORACLE ONLY */
  function setExchangeRate(address token, uint256 usdExchangeRate) public; // uses decimals from token
}
```

### Changes to the original interface:

**addEmployee :**

Originally the interface does not return any value however subsequent methods in the contract depend on knowning the ID. Therefore I have added a return value so that the caller can record the Employee ID and use it later.

**addFunds :**

Originally the interface does not return any value, however I felt that it would be a cool "easter egg" to send a thank you message back to the originator of the transaction.

**addTokenFunds /  tokenFallback :**

Originally the interface alluded to this functionality and I added the `tokenFallback()` method to the contract so to be ERC223 compliant. I did not implement the `addTokenFunds()` method because it is not required, any user can transfer tokens to the contract without calling an explicit method for receiving tokens.

**scapeHatch :**

I've changed the name of this method to `escapeHatch()` because I believe this is a typo. I've also added another method to this contract called `backToBusiness()`, this gives the contract owner the ability to reactivate the contract after a potential emergency has been resolved.

**setExchangeRate :**

I've made this method polymorphic because Ether does not have an address and so we require a way to distinguish Ether rates from the token rates, which are supplied a contract address. Within the contract Ether's "address" is treated as the contract's own address, this is allow for uniformity when employees update their payment distribution preferrences, it allows a Employee to send data as follows:

```javascript

var tokens = [
  '<contract_address>',
  '0xa74476443119A942dE498590Fe1f2454d7D4aC0d',
  '0xd26114cd6EE289AccF82350c8d8487fedB8A0C07',
  '0x960b236A07cf122663c4303350609A66A7B288C0'
];

var distribution = [
  20,
  10,
  10,
  60
];

```
