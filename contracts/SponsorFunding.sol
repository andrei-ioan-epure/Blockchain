// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ICrowdFundingToken {
    function buyTokens() external payable returns (uint256);
}

contract SponsorFunding {
    address public owner;
    address public tokenAddress;
    uint256 public sponsorshipPercentage;
    
    mapping(address => bool) public authorizedCrowdFundings;
    
    event SponsorshipProvided(address indexed crowdFunding, uint256 amount);
    event SponsorshipFailed(address indexed crowdFunding, uint256 required, uint256 available);
    event TokensPurchased(uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event CrowdFundingAuthorized(address indexed crowdFunding);
    event CrowdFundingDeauthorized(address indexed crowdFunding);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedCrowdFundings[msg.sender], "Not authorized");
        _;
    }
    
    constructor(address _tokenAddress, uint256 _sponsorshipPercentage) {
        require(_tokenAddress != address(0), "Invalid token");
        require(_sponsorshipPercentage > 0 && _sponsorshipPercentage <= 100, "Invalid percentage");
        owner = msg.sender;
        tokenAddress = _tokenAddress;
        sponsorshipPercentage = _sponsorshipPercentage;
    }
    
    function authorizeCrowdFunding(address _crowdFunding) public onlyOwner {
        require(_crowdFunding != address(0), "Invalid address");
        require(!authorizedCrowdFundings[_crowdFunding], "Already authorized");
        authorizedCrowdFundings[_crowdFunding] = true;
        emit CrowdFundingAuthorized(_crowdFunding);
    }
    
    function deauthorizeCrowdFunding(address _crowdFunding) public onlyOwner {
        require(authorizedCrowdFundings[_crowdFunding], "Not authorized");
        authorizedCrowdFundings[_crowdFunding] = false;
        emit CrowdFundingDeauthorized(_crowdFunding);
    }
    
    function buyTokensForSponsorship() public payable onlyOwner returns (uint256) {
        require(msg.value > 0, "Send ETH");
        ICrowdFundingToken tokenContract = ICrowdFundingToken(tokenAddress);
        uint256 tokenAmount = tokenContract.buyTokens{value: msg.value}();
        emit TokensPurchased(tokenAmount);
        return tokenAmount;
    }
    
    function provideSponsor(address crowdFundingAddress) external onlyAuthorized {
        require(crowdFundingAddress == msg.sender, "Invalid caller");
        
        IERC20 token = IERC20(tokenAddress);
        uint256 crowdFundingBalance = token.balanceOf(crowdFundingAddress);
        uint256 sponsorshipAmount = (crowdFundingBalance * sponsorshipPercentage) / 100;
        uint256 ourBalance = token.balanceOf(address(this));
        
        if (ourBalance >= sponsorshipAmount && sponsorshipAmount > 0) {
            require(token.transfer(crowdFundingAddress, sponsorshipAmount), "Transfer failed");
            emit SponsorshipProvided(crowdFundingAddress, sponsorshipAmount);
        } else {
            emit SponsorshipFailed(crowdFundingAddress, sponsorshipAmount, ourBalance);
        }
    }
    
    function getBalance() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }
    
    function withdrawTokens(uint256 _amount) public onlyOwner {
        require(_amount > 0, "Invalid amount");
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= _amount, "Insufficient balance");
        require(token.transfer(owner, _amount), "Transfer failed");
        emit TokensWithdrawn(owner, _amount);
    }
    
    function withdrawETH() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "ETH transfer failed");
        emit ETHWithdrawn(owner, balance);
    }
    
    receive() external payable {}
}