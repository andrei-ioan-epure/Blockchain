// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ISponsorFunding {
    function provideSponsor(address crowdFundingAddress) external;
}

interface IDistributeFunding {
    function receiveTokens() external;
}

contract CrowdFunding {
    address public owner;
    address public tokenAddress;
    address public sponsorAddress;
    address public distributeAddress;
    uint256 public fundingGoal;
    uint256 public currentAmount;
    
    enum State { Nefinantat, Prefinantat, Finantat }
    State public currentState;
    
    mapping(address => uint256) public contributions;
    
    event ContributionReceived(address indexed contributor, uint256 amount);
    event WithdrawalMade(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalAmount);
    event StateChanged(State newState);
    event SponsorshipReceived(uint256 amount);
    event FundsTransferred(address indexed to, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier inState(State _state) {
        require(currentState == _state, "Invalid state");
        _;
    }
    
    constructor(address _tokenAddress, uint256 _fundingGoal) {
        require(_tokenAddress != address(0), "Invalid token");
        require(_fundingGoal > 0, "Invalid goal");
        owner = msg.sender;
        tokenAddress = _tokenAddress;
        fundingGoal = _fundingGoal;
        currentAmount = 0;
        currentState = State.Nefinantat;
    }
    
    function setSponsorAddress(address _sponsorAddress) public onlyOwner {
        require(_sponsorAddress != address(0), "Invalid address");
        require(currentState == State.Nefinantat, "Cannot change after started");
        sponsorAddress = _sponsorAddress;
    }
    
    function setDistributeAddress(address _distributeAddress) public onlyOwner {
        require(_distributeAddress != address(0), "Invalid address");
        require(currentState != State.Finantat, "Cannot change after finalized");
        distributeAddress = _distributeAddress;
    }
    
    function contribute(uint256 _amount) public inState(State.Nefinantat) {
        require(_amount > 0, "Amount must be positive");
        require(currentAmount + _amount <= fundingGoal, "Exceeds goal");
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        contributions[msg.sender] += _amount;
        currentAmount += _amount;
        emit ContributionReceived(msg.sender, _amount);
        
        if (currentAmount >= fundingGoal) {
            currentState = State.Prefinantat;
            emit GoalReached(currentAmount);
            emit StateChanged(State.Prefinantat);
        }
    }
    
    function withdraw(uint256 _amount) public inState(State.Nefinantat) {
        require(_amount > 0, "Amount must be positive");
        require(contributions[msg.sender] >= _amount, "Insufficient contribution");
        
        contributions[msg.sender] -= _amount;
        currentAmount -= _amount;
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        emit WithdrawalMade(msg.sender, _amount);
    }
    
    function requestSponsorship() public onlyOwner inState(State.Prefinantat) {
        require(sponsorAddress != address(0), "Sponsor not set");
        
        uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));
        ISponsorFunding(sponsorAddress).provideSponsor(address(this));
        uint256 balanceAfter = IERC20(tokenAddress).balanceOf(address(this));
        
        uint256 sponsorshipAmount = balanceAfter - balanceBefore;
        currentState = State.Finantat;
        
        emit SponsorshipReceived(sponsorshipAmount);
        emit StateChanged(State.Finantat);
    }
    
    function finalizeAndTransfer() public onlyOwner inState(State.Finantat) {
        require(distributeAddress != address(0), "Distribute not set");
        
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance > 0, "No funds");
        
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(distributeAddress, balance), "Transfer failed");
        emit FundsTransferred(distributeAddress, balance);
        
        IDistributeFunding(distributeAddress).receiveTokens();
    }
    
    function getState() public view returns (string memory) {
        if (currentState == State.Nefinantat) return "nefinantat";
        if (currentState == State.Prefinantat) return "prefinantat";
        return "finantat";
    }
    
    function getContribution(address _contributor) public view returns (uint256) {
        return contributions[_contributor];
    }
    
    function getRemainingAmount() public view returns (uint256) {
        if (currentAmount >= fundingGoal) return 0;
        return fundingGoal - currentAmount;
    }
}