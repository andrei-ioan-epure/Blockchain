// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DistributeFunding {
    struct Shareholder {
        address addr;
        uint256 percentage;
        bool hasWithdrawn;
        bool exists;
    }
    
    address public owner;
    address public tokenAddress;
    address public crowdFundingAddress;
    uint256 public totalReceived;
    bool public fundsReceived;
    
    Shareholder[] public shareholders;
    mapping(address => uint256) public shareholderIndex;
    uint256 public totalAllocatedPercentage;
    
    event ShareholderAdded(address indexed shareholder, uint256 percentage);
    event ShareholderUpdated(address indexed shareholder, uint256 oldPercentage, uint256 newPercentage);
    event ShareholderRemoved(address indexed shareholder);
    event FundsReceived(uint256 amount, address indexed from);
    event ShareWithdrawn(address indexed shareholder, uint256 amount);
    event RemainingWithdrawn(address indexed owner, uint256 amount);
    event CrowdFundingSet(address indexed crowdFunding);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier beforeFundsReceived() {
        require(!fundsReceived, "Cannot modify after funds received");
        _;
    }
    
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token");
        owner = msg.sender;
        tokenAddress = _tokenAddress;
        totalReceived = 0;
        fundsReceived = false;
        totalAllocatedPercentage = 0;
    }
    
    function setCrowdFundingAddress(address _crowdFundingAddress) public onlyOwner beforeFundsReceived {
        require(_crowdFundingAddress != address(0), "Invalid address");
        crowdFundingAddress = _crowdFundingAddress;
        emit CrowdFundingSet(_crowdFundingAddress);
    }
    
    function addShareholder(address _shareholder, uint256 _percentage) public onlyOwner beforeFundsReceived {
        require(_shareholder != address(0), "Invalid address");
        require(_percentage > 0, "Invalid percentage");
        
        bool exists = false;
        uint256 index = 0;
        
        for (uint256 i = 0; i < shareholders.length; i++) {
            if (shareholders[i].addr == _shareholder) {
                exists = true;
                index = i;
                break;
            }
        }
        
        if (exists) {
            uint256 oldPercentage = shareholders[index].percentage;
            require(totalAllocatedPercentage - oldPercentage + _percentage <= 100, "Exceeds 100%");
            totalAllocatedPercentage = totalAllocatedPercentage - oldPercentage + _percentage;
            shareholders[index].percentage = _percentage;
            emit ShareholderUpdated(_shareholder, oldPercentage, _percentage);
        } else {
            require(totalAllocatedPercentage + _percentage <= 100, "Exceeds 100%");
            Shareholder memory newShareholder = Shareholder({
                addr: _shareholder,
                percentage: _percentage,
                hasWithdrawn: false,
                exists: true
            });
            shareholders.push(newShareholder);
            shareholderIndex[_shareholder] = shareholders.length - 1;
            totalAllocatedPercentage += _percentage;
            emit ShareholderAdded(_shareholder, _percentage);
        }
    }
    
    function receiveTokens() public beforeFundsReceived {
        require(shareholders.length > 0, "No shareholders");
        require(crowdFundingAddress != address(0), "CrowdFunding not set");
        require(msg.sender == crowdFundingAddress, "Only CrowdFunding contract");
        
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens");
        
        totalReceived = balance;
        fundsReceived = true;
        emit FundsReceived(balance, msg.sender);
    }
    
    function withdrawShare() public {
        require(fundsReceived, "Funds not received");
        
        bool found = false;
        uint256 index = 0;
        for (uint256 i = 0; i < shareholders.length; i++) {
            if (shareholders[i].addr == msg.sender) {
                found = true;
                index = i;
                break;
            }
        }
        
        require(found, "Not a shareholder");
        require(!shareholders[index].hasWithdrawn, "Already withdrawn");
        
        uint256 amount = (totalReceived * shareholders[index].percentage) / 100;
        require(amount > 0, "No tokens");
        
        shareholders[index].hasWithdrawn = true;
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Transfer failed");
        emit ShareWithdrawn(msg.sender, amount);
    }
    
    function withdrawRemaining() public onlyOwner {
        require(fundsReceived, "Funds not received");
        
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No remaining");
        require(token.transfer(owner, balance), "Transfer failed");
        emit RemainingWithdrawn(owner, balance);
    }
    
    function getShareholder(address _addr) public view returns (uint256 percentage, bool hasWithdrawn, bool exists) {
        for (uint256 i = 0; i < shareholders.length; i++) {
            if (shareholders[i].addr == _addr) {
                return (shareholders[i].percentage, shareholders[i].hasWithdrawn, true);
            }
        }
        return (0, false, false);
    }
    
    function getShareholderCount() public view returns (uint256) {
        return shareholders.length;
    }
    
    function getTotalAllocated() public view returns (uint256) {
        return totalAllocatedPercentage;
    }
    
    function getShareholderAtIndex(uint256 _index) public view returns (address addr, uint256 percentage, bool hasWithdrawn) {
        require(_index < shareholders.length, "Index out of bounds");
        Shareholder memory sh = shareholders[_index];
        return (sh.addr, sh.percentage, sh.hasWithdrawn);
    }
}