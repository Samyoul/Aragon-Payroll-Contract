# Aragon Payroll Contract

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
  '<contract_address>',                         //ETH
  '0xa74476443119A942dE498590Fe1f2454d7D4aC0d', //GNT
  '0xd26114cd6EE289AccF82350c8d8487fedB8A0C07', //OMG
  '0x960b236A07cf122663c4303350609A66A7B288C0'  //ANT
];

var distribution = [
  20, //ETH
  10, //GNT
  10, //OMG
  60  //ANT
];

```

### Additional Methods

**switchOracle :**

Functionality that allows the contract owner to change the oracle address if needed, without this functionality the contract would become useless if the oracle address became no longer function or reliable.

**authoriseToken :**

Functionality to allow the contract owner to permit the contract to accept and pay out tokens from a particular address. Useful because ERC223 tokens can be blocked from being transferred if the contract owner has not whitelisted them.

**updateRates :**

Functionality that allows the contract owner to initiate request to the oracle to update the exchange rates for each of the tokens that are authorised to be used with this contract.

## Points of Improvement

As with all software the scope for improvement is never ending, with this contract specifically I've identified a number of areas that require additional attention.

**calculatePayrollRunway :**

I believe that the assumption of this method was to return how many days until the contract has ran out of funds. The problem with this approach is that the contract manages multiple fund balances, each of which can run out independantly of each other, meaning you need to know not only how many days until you run out of funds, but which fund is due to run out. Currently this method only returns a number of days.

The method `calculatePayrollRunway()`'s signature should be changed because it would be more helpful to know not only which tokens are running low, not just how many days until we run out. It would be better if this method returned the USD and token balances of each token contract address along with the number of days each token has left until it runs out.

**Token Contract Address Changes :**

The current setup of this contract means that if an organisation changed its token contract address (like in the case with Hacker Gold), the whole contract would break. The contract stores multiple referrences to token addresses, without a means to refer to and change these, this would leave the contract very broken. The contract therefore needs owner only functionality to migrate one token address to another. This would likely require a refactor of the current structure.
