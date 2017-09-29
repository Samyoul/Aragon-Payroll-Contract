pragma solidity ^0.4.8;

import "./PayrollInterface.sol";

/**
 * @title Payroll contract, for paying employees as per their prefrences
 * @author Samuel Hawksby-Robinson <samuel@samyoul.com>
 */
contract Payroll is PayrollInterface {
    
    // Structs
    struct Employee {
        address accountAddress;
        address[] allowedTokens;
        uint256 yearlyUSDSalary;
    }
    
    // Users
    address owner;
    mapping (uint256 => Employee) employees;
    mapping (address => uint256) employeeIds;
    address oracle;
    
    mapping (address => bool) authorised;
    
    // States
    bool escaped = false;
    
    // Calculation data
    uint256 lastEmployeeId = 0;
    mapping (address => uint256) usdExchangeRate;
    
    // Constructor
    function Payroll(address _oracle) public{
        owner = msg.sender;
        oracle = _oracle;
    }

    // Modifiers
    /**
     * If owner
     * @dev Checks if sender is the contract creator, on fail revert.
     */
    modifier ifOwner(){
        if(owner != msg.sender){
            revert();
        }
        _;
    }
    
    /**
     * If authorised
     * @dev Checks if sender is either the contract creator or in the list of authorised addresses
     */
    modifier ifAuthorised(){
        if(authorised[msg.sender] || owner == msg.sender){
            _;
        }
        else{
            revert();
        }
    }
    
    /**
     * If not escaped
     * @dev Checks if contract is in "Escape Hatch Mode" and if the sender is authorised.
     * @dev If the contract is in "Escape Hatch Mode" and sender is not authorised revert
     */
    modifier ifNotEscaped(){
        if(escaped && !(authorised[msg.sender] || owner == msg.sender)){
           revert();
        }
        _;
    }
    
    /**
     * If oracle
     * @dev Checks if sender is the approved oracle
     */
    modifier ifOracle(){
        if(oracle != msg.sender){
            revert();
        }
        _;
    }
    
    /* OWNER ONLY */
    /**
     * Add employee
     * @dev Adds a new Employee to the records
     * @param accountAddress is the public key for the Employee
     * @param allowedTokens is a list of tokens that the Employee is willing to be paid with
     * @param initialYearlyUSDSalary is the Employee's annual USD salary
     */
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) public ifOwner returns(uint256 employeeId){
        employeeId = lastEmployeeId++;
        employees[employeeId] = Employee(accountAddress, allowedTokens, initialYearlyUSDSalary);
        employeeIds[msg.sender] = employeeId;
        return employeeId;
    }
    
    /**
     * Set employee salary
     * @dev Sets an employee's salary
     * @param employeeId is the identifier for the Employee
     * @param yearlyUSDSalary is the new Employee's annual USD salary
     */
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public ifOwner{
        Employee storage E = employees[employeeId];
        E.yearlyUSDSalary = yearlyUSDSalary;
    }
    
    /**
     * Remove Employee
     * @dev Removes an Employee from the list of employees
     * @param employeeId is the identifier for the Employee
     */
    function removeEmployee(uint256 employeeId) public ifOwner{
        delete employees[employeeId];
    }
    
    /**
     * Switch oracle
     * @dev Allows owner to change the oracle public key
     * @param _oracle is the public key of the USD exchange oracle
     */
    function switchOracle(address _oracle) public ifOwner{
        oracle = _oracle;
    }
    
    
    // Authorised addresses only
    /**
     * Escape hatch
     * @dev 
     */
    function escapeHatch() public ifAuthorised{
        escaped = true;
    }
    
    function backToBusiness() public ifAuthorised{
        escaped = false;
    }

    // Publicly open functions
    /**
     * Add funds
     * @dev Allows a user to transfer Ether to the contract balance
     */
    function addFunds() payable public ifNotEscaped{
        
    }

    /**
     * Add Token Funds
     * @dev Allows a user to transfer tokens to the contract address
     */
    function addTokenFunds() public ifNotEscaped{
        
    }// Use approveAndCall or ERC223 tokenFallback

    // Public getters
  function getEmployeeCount() public constant returns (uint256);
  function getEmployee(uint256 employeeId) public constant returns (address employee); // Return all important info too

  function calculatePayrollBurnrate() public constant returns (uint256); // Monthly usd amount spent in salaries
  function calculatePayrollRunway() public constant returns (uint256); // Days until the contract can run out of funds

  /* EMPLOYEE ONLY */
  function determineAllocation(address[] tokens, uint256[] distribution) public; // only callable once every 6 months
  function payday() public ifNotEscaped{
      
  } // only callable once a month

    /* ORACLE ONLY */
    function setExchangeRate(address token, uint256 usdExchangeRate) public ifOracle ifNotEscaped{
        
    } // uses decimals from token
}
