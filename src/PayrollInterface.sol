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
  function calculatePayrollRunway() public returns (uint256); // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution) public; // only callable once every 6 months
  function payday() public; // only callable once a month

  /* ORACLE ONLY */
  function setExchangeRate(address token, uint256 usdExchangeRate) public; // uses decimals from token
}
