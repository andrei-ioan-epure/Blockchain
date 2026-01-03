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
    
    event SponsorshipProvided(address indexed crowdFunding, uint256 amount);
    event SponsorshipFailed(address indexed crowdFunding, uint256 required, uint256 available);
    event TokensPurchased(uint256 amount);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(address _tokenAddress, uint256 _sponsorshipPercentage) {
        require(_tokenAddress != address(0), "Invalid token");
        require(_sponsorshipPercentage > 0 && _sponsorshipPercentage <= 100, "Invalid percentage");
        owner = msg.sender;
        tokenAddress = _tokenAddress;
        sponsorshipPercentage = _sponsorshipPercentage;
    }
    
    function buyTokensForSponsorship() public payable onlyOwner returns (uint256) {
        require(msg.value > 0, "Send ETH");
        ICrowdFundingToken tokenContract = ICrowdFundingToken(tokenAddress);
        uint256 tokenAmount = tokenContract.buyTokens{value: msg.value}();
        emit TokensPurchased(tokenAmount);
        return tokenAmount;
    }
    
    function provideSponsor(address crowdFundingAddress) external {
        require(crowdFundingAddress != address(0), "Invalid address");
        
        IERC20 token = IERC20(tokenAddress);
        uint256 crowdFundingBalance = token.balanceOf(crowdFundingAddress);
        uint256 sponsorshipAmount = (crowdFundingBalance * sponsorshipPercentage) / 100;
        uint256 ourBalance = token.balanceOf(address(this));
        
        if (ourBalance >= sponsorshipAmount) {
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