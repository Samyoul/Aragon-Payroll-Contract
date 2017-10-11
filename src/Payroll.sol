pragma solidity ^0.4.17;

import "./PayrollInterface.sol";
import "github.com/ConsenSys/Tokens/contracts/HumanStandardToken.sol";
import "github.com/pipermerriam/ethereum-datetime/contracts/DateTime.sol";
import "github.com/Dexaran/ERC223-token-standard/token/ERC223/ERC223_receiving_contract.sol";

/**
 * @title Payroll contract, for paying employees as per their prefrences
 * @author Samuel Hawksby-Robinson <samuel@samyoul.com>
 */
contract Payroll is PayrollInterface, ERC223ReceivingContract {
    /**
     * 
     * CONTRACT ATTRIBUTES
     * 
     */
     
    //--------------------------------//
    //            USERS               //
    //--------------------------------//
    /**
     * Employee
     * @dev Data structure representing an Employee managed by the contract
     * @param accountAddress is the Ethereum address associated with the Employee
     * @param allowedTokens is an array of token contract addresses that Employee is permitted to be paid with
     * @param requestedTokens is an array of token contract addresses the Employee wishes to be paid with
     * @param tokenDistribution is an array of percentages representing how the Employee wishes to have thier payment split between tokens/Ether
     * @param yearlyUSDSalary is the Employee's salary for a year in usdRate
     * @param lastUpdatedDistribution is a timestamp representing the last time the Employee updated their distribution prefrences
     * @param lastPayDay is a timestamp representing the last time the Employee collected their pay
     */
    struct Employee {
        address accountAddress;
        address[] allowedTokens;
        address[] requestedTokens;
        uint256[] tokenDistribution;
        uint256 yearlyUSDSalary;
        uint lastUpdatedDistribution;
        uint lastPayDay;
    }
    
    /**
     * owner
     * @dev The address of the contract owner.
     */
    address owner;
    
    /**
     * employees
     * @dev mapping of employee ids to the respective Employee data structures
     */
    mapping (uint256 => Employee) employees;
    
    /**
     * employee ids
     * @dev mapping of the employee ids to the respective employee's address
     */
    mapping (address => uint256) employeeIds;
    
    /**
     * oracle
     * @dev The address of the authorised oracle.
     */
    address oracle;
    
    
    //--------------------------------//
    //            STATES              //
    //--------------------------------//
    /**
     * escaped
     * @dev Is the contract in emergency escaped mode? In escape mode most of the functionality of the contract is prohibited.
     */
    bool escaped = false;
    
    
    //--------------------------------//
    //        CALCULATION DATA        //
    //--------------------------------//
    /**
     * last employee ids
     * @dev The last id given to an Employee
     */
    uint256 internal lastEmployeeId = 0;
    
    /**
     * employee count
     * @dev The number of employees managed by the contract
     */
    uint256 internal employeeCount = 0;
    
    /**
     * Total Yearly USD Salary
     * @dev The amount all Employees are paid annually in USD 
     */
    uint256 internal totalYearlyUSDSalary = 0;
    
    /**
     * Ether USD Rate
     * @dev The rate at which 1 Ether token can be purchased with USD
     */
    uint256 internal etherUSDRate;
    
    /**
     * Last Token Id
     * @dev The last id given to a Token
     */
    uint256 internal lastTokenId = 0;
    
    
    //--------------------------------//
    //           TOKENS               //
    //--------------------------------//
    /**
     * Token
     * @dev Data structure representing an ERC20/223 token and its USD Exchange Rate
     * @param tokenAddress is the address of the token CONTRACT
     * @param usdRate is the rate at which one Ether token can be purchased with USD
     */
    struct Token {
        address tokenAddress;
        uint256 usdRate;
    }
    
    /**
     * Tokens Handled
     * @dev A list of Tokens managed by the contract
     */
    Token[] tokensHandled;
    
    /**
     * Token Ids
     * @dev mapping of token addresses to Token ids
     */
    mapping(address => uint256) tokenIds;
    
    
    //--------------------------------//
    //           EVENTS               //
    //--------------------------------//
    /**
     * Tokens Received
     * @dev a log of incomming tokens.
     * @param _token is the address of the token contract
     * @param _from is the address of transaction originator
     * @param _value is the amount of tokens transfered to this contract
     */
    event TokensReceived(
        address _token,
        address _from,
        uint256 _value
    );
    
    
    /**
     * 
     * CONTRACT METHODS
     * 
     */
    
    
    //--------------------------------//
    //         CONSTRUCTOR            //
    //--------------------------------//
    function Payroll(address _oracle) public{
        owner = msg.sender;
        oracle = _oracle;
    }


    //--------------------------------//
    //          MODIFIERS             //
    //--------------------------------//
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
     * If not escaped
     * @dev Checks if contract is in "Escape Hatch Mode" and if the sender is authorised.
     * @dev If the contract is in "Escape Hatch Mode" and sender is not authorised revert
     */
    modifier ifNotEscaped(){
        if(escaped && owner != msg.sender){
           revert();
        }
        _;
    }
    
    /**
     * If employee
     * @dev Check if the sender is in the employee list, on fail revert.
     */
    modifier ifEmployee(){
        if(!(employeeIds[msg.sender] > 0)){
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
    
    
    //--------------------------------//
    //          OWNER ONLY            //
    //--------------------------------//
    /**
     * Add employee
     * @dev Adds a new Employee to the records
     * @param accountAddress is the public key for the Employee
     * @param allowedTokens is a list of tokens that the Employee is willing to be paid with
     * @param initialYearlyUSDSalary is the Employee's annual USD salary
     * @return employeeId the ID of the employee
     */
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) public ifOwner ifNotEscaped returns(uint256 employeeId){
        require(initialYearlyUSDSalary > 0);
        
        // Check that the tokens are in the managed list
        for (uint i = 0; i < allowedTokens.length; i++) {
            if(!(tokenIds[allowedTokens[i]] > 0)){
                revert();
            }
        }
        
        employeeId = lastEmployeeId++;
        employeeCount++;
        
        address[] memory defaultToken = new address[](1);
        defaultToken[0] = this; // NOTE: If the token address is this Ether will be transfered.
        uint256[] memory defaultDistribution = new uint256[](1);
        defaultDistribution[0] = 100;
        
        employees[employeeId] = Employee(
            accountAddress,
            allowedTokens,
            defaultToken,
            defaultDistribution,
            initialYearlyUSDSalary,
            0,
            0
        );
        employeeIds[msg.sender] = employeeId;
        
        _updateTotalYearlySalaries(0, initialYearlyUSDSalary);
        return employeeId;
    }
    
    /**
     * Set employee salary
     * @dev Sets an employee's salary
     * @param employeeId is the identifier for the Employee
     * @param yearlyUSDSalary is the new Employee's annual USD salary
     */
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) public ifOwner ifNotEscaped{
        require(yearlyUSDSalary > 0);
        _adjustSalary(employeeId, yearlyUSDSalary);
    }
    
    /**
     * Remove Employee
     * @dev Removes an Employee from the list of employees
     * @param employeeId is the identifier for the Employee
     */
    function removeEmployee(uint256 employeeId) public ifOwner ifNotEscaped{
        _adjustSalary(employeeId, 0);
        delete employees[employeeId];
        employeeCount--;
    }
    
    /**
     * Switch oracle
     * @dev Allows owner to change the oracle public key
     * @param _oracle is the public key of the USD exchange oracle
     */
    function switchOracle(address _oracle) public ifOwner ifNotEscaped{
        oracle = _oracle;
    }
    
    /**
     * Adjust salaries
     * INTERNAL
     * @dev Updates an employee's salary and global salaries
     * @param employeeId is the identifier for the Employee
     * @param newSalary is the value of the employee's new salary
     */
    function _adjustSalary(uint256 employeeId, uint256 newSalary) internal ifNotEscaped{
        Employee storage E = employees[employeeId];
        _updateTotalYearlySalaries(E.yearlyUSDSalary, newSalary);
        E.yearlyUSDSalary = newSalary;
    }
    
    /**
     * Update total yearly salaries
     * INTERNAL
     * @dev Updates the global salary value, the function presumes update is performed on an Employee basis
     * @param currentSalary is the last salary value an employee had
     * @param newSalary is the new salary value an employee will be assigned
     */
    function _updateTotalYearlySalaries(uint256 currentSalary, uint256 newSalary) internal{
        totalYearlyUSDSalary += newSalary - currentSalary;
    }
    
    /**
     * Authorised Token
     * @dev Authorise a new token to be managed by the contract
     * @param _token is the address of the new token to authorise
     */
    function authoriseToken(address _token) public ifOwner ifNotEscaped{
        // Are we managing this token already?
        if((tokenIds[msg.sender] > 0)){
            revert();
        }
        
        Token memory newToken = Token(_token, 0);
        uint256 tokenId = lastTokenId++;
        tokenIds[_token] = tokenId;
        tokensHandled[tokenId] = newToken;
    }
    
    /**
     * Escape hatch
     * @dev places the contract into an emergency mode restricts contract functionality
     * @dev allows time for the developers to fix a problem without a hacker being able to continously exploit a bug in the contract
     */
    function escapeHatch() public ifOwner{
        escaped = true;
        
        //Rescue all the tokens
        for (uint i = 0; i < tokensHandled.length; i++) {
            Token storage token = tokensHandled[i];
            HumanStandardToken humanToken = HumanStandardToken(token.tokenAddress);
            humanToken.transfer(msg.sender, humanToken.balanceOf(this));
        }
        
        // Rescue the Ether
        msg.sender.transfer(this.balance);
    }
    
    /**
     * Back To Business
     * @dev reactivates the contract and allows normal functionality
     */
    function backToBusiness() public ifOwner{
        escaped = false;
    }
    
    /**
     * Update Rates
     */
    function updateRates() public ifOwner ifNotEscaped{
        _updateEtherUSDRate();
        _updateTokenUSDRates();
    }
    
    function _updateEtherUSDRate() internal{
        // functionality that interacts with an API Endpoint abstraction contract
    }

    function _updateTokenUSDRates() internal{
        // functionality that interacts with an API Endpoint abstraction contract
    }


    //--------------------------------//
    //         PUBLIC METHODS         //
    //--------------------------------//
    /**
     * Add funds
     * @dev Allows a user to transfer Ether to the contract balance
     */
    function addFunds() payable public ifNotEscaped returns(string){
        return "Thanks for the Ether :D, Love from Aragon <3.";
    }

    /**
     * Token Fallback
     * @dev Allows a user to transfer tokens to the contract address if the token contract is ERC223 complient
     */
    function tokenFallback(address _from, uint _value, bytes _data) ifNotEscaped {
        // Check token is in the managed list
        if(!(tokenIds[msg.sender] > 0)){
            revert();
        }
        
        TokensReceived(msg.sender, _from, _value);
    }

    
    //--------------------------------//
    //        PUBLIC GETTERS          //
    //--------------------------------//
    /**
     * Get employee count
     * @dev returns the number of employees managed by the contract
     */
    function getEmployeeCount() public constant returns (uint256){
        return employeeCount;
    }
    
    /**
     * Get employee
     * @dev Returns important data stored about an employee based on a given ID
     * @param employeeId is the identifier for the Employee
     * @return accountAddress is the address of the Employee
     * @return allowedTokens is a list of the tokens the Employee is allowed to be paid in
     * @return yearlyUSDSalary is the Employee's annual USD salary
     * @return lastPayDay is the timestemp representing the last time the employee fired the payday function
     */
    function getEmployee(uint256 employeeId) public constant returns (
        address accountAddress,
        address[] allowedTokens,
        uint256 yearlyUSDSalary,
        uint lastPayDay
    ){
        Employee storage E = employees[employeeId];
        
        accountAddress = E.accountAddress;
        allowedTokens = E.allowedTokens;
        yearlyUSDSalary = E.yearlyUSDSalary;
        lastPayDay = E.lastPayDay;
    }

    /**
     * Calculate Payroll Burnrate
     * @dev Caluclates the current rate in USD that the contract spends per month
     * @return the current monthly spend value in USD
     */
    function calculatePayrollBurnrate() public constant returns (uint256){
        return totalYearlyUSDSalary / 12;
    }

    /**
     * Calculate Payroll Runway
     * @dev Calculates the number of days before the contract will run out of funds
     * @return the number of days before the contract will run out of funds
     */
    function calculatePayrollRunway() public constant returns (uint256){
        // Get ether balance in USD
        uint256 totalUSDBalance = this.balance * etherUSDRate;
        
        // totalUSDBalance = get the USD balance foreach token balance, then total it
        for (uint i = 0; i < tokensHandled.length; i++) {
            Token storage token = tokensHandled[i];
            HumanStandardToken humanToken = HumanStandardToken(token.tokenAddress);
            totalUSDBalance += (humanToken.balanceOf(this) * token.usdRate);
        }
        
        return (totalUSDBalance / totalYearlyUSDSalary / 365);
    }
    

    //--------------------------------//
    //        EMPLOYEE ONLY           //
    //--------------------------------//
    /**
     * Determine allocation
     * @dev An employee can set the how they want to be paid spliting their payment among a list of tokens
     * @dev The employee can only set this data everty 6 months.
     * @param tokens is a list of token addresses the sender wishes to be paid with
     * @param distribution is a list of integers that define the percentage that user wishes each token factor as part of their payment
     */
    function determineAllocation(address[] tokens, uint256[] distribution) public ifNotEscaped ifEmployee{
        Employee storage employee = employees[employeeIds[msg.sender]];
        
        // Has six months passed since last allocation?
        if(!(now > _incrementMonths(6, employee.lastUpdatedDistribution))){
            revert();
        }
        else{
            // Check both arrays have the same length
            if(tokens.length != distribution.length){
                revert();
            }
            
            // Check addresses match authorised addresses
            for (uint i = 0; i < tokens.length; i++) {
                bool result = false;
                
                for (uint x = 0; x < employee.allowedTokens.length; x++) {
                    if(tokens[i] == employee.allowedTokens[x]){
                        result = true;
                    }
                }
                
                if(!result){
                    revert();
                }
            }
            
            // Check that distribution adds upto 100
            uint256 distributionTotal = 0;
            for(uint t = 0; t < distribution.length; t++){
                distributionTotal += distribution[t];
            }
            if(distributionTotal != 100){
                revert();
            }
            
            employee.requestedTokens = tokens;
            employee.tokenDistribution = distribution;
            employee.lastUpdatedDistribution = now;
        }
    }

    /**
     * Pay day.
     * @dev Called by an employee to claim their monthly pay.
     * @dev This is only callable once per month by an employee
     */
    function payday() public ifNotEscaped ifEmployee{
        //TODO check make a count so if a employee misses a payment they can take it later.
        Employee storage employee = employees[employeeIds[msg.sender]];
        
        // Has there been at least 1 month since the last payday?
        if(!(now > _incrementMonths(1, employee.lastPayDay))){
            revert();
        }
        
        for (uint i = 0; i < employee.requestedTokens.length; i++) {
            
            // Calculate the amount of each token you need to pay, split monthly pay by proportion
            uint256 proportion = (employee.yearlyUSDSalary / 12) / employee.tokenDistribution[i];
            uint256 tokenSplit;
            
            // Divide proportion by exchange rate to get the split
            // Check requestedToken is this, handle as Ether
            if (address(employee.requestedTokens[i]) == address(this)){
                tokenSplit = proportion / etherUSDRate;
                msg.sender.transfer(tokenSplit);
            }
            else{
                Token storage token = tokensHandled[tokenIds[employee.requestedTokens[i]]];
                tokenSplit = proportion / token.usdRate;
                
                HumanStandardToken humanToken = HumanStandardToken(token.tokenAddress);
                humanToken.transfer(msg.sender, tokenSplit);
            }
            
        }
        
    }
    
    /**
     * Increment months
     * INTERNAL
     * @dev takes a timestamp and increments it by a number of months
     * @param _months is the number of months to increment the timestamp by
     * @param _timestamp is the date to increase by the number of months
     */
    function _incrementMonths(uint16 _months, uint _timestamp) internal returns (uint){
        DateTime dateTime = DateTime(address(0x1a6184cd4c5bea62b0116de7962ee7315b7bcbce));
        uint16 year = dateTime.getYear(_timestamp);
        uint16 month = dateTime.getMonth(_timestamp);
        
        month += _months;
        while(month > 12){
            month -= 12;
            year++;
        }
        
        // get new timestamp
        return dateTime.toTimestamp(
            year,
            uint8(month),
            dateTime.getDay(_timestamp),
            dateTime.getHour(_timestamp),
            dateTime.getMinute(_timestamp),
            dateTime.getSecond(_timestamp)
        );
    }


    //--------------------------------//
    //         ORACLE ONLY            //
    //--------------------------------//
    /**
     * Set Ether USD Exchange rate
     * @dev Callback method only callable by the authorised oracle, sets the ETH/USD exchange rate
     * @param usdExchangeRate is the rate at which 1 ether can be purchased with USD
     */
    function setEtherUSDExchangeRate(uint256 usdExchangeRate) public ifOracle ifNotEscaped{
        etherUSDRate = usdExchangeRate;
    }
    
    /**
     * Set Token USD Exchange Rate
     * @dev Callback methonf only callable by the authorised oracle, sets the <token>/USD exchange rate
     * @param _token is the contract address that maintains a specific Token
     * @param usdExchangeRate is the rate at which 1 token can be purchased with USD
     */
    function setTokenUSDExchangeRate(address _token, uint256 usdExchangeRate) public ifOracle ifNotEscaped{
        Token storage token = tokensHandled[tokenIds[_token]];
        HumanStandardToken humanToken = HumanStandardToken(token.tokenAddress);
        token.usdRate = usdExchangeRate * humanToken.decimals();
    }
}
