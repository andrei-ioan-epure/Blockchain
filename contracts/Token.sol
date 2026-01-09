// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdFundingToken {
    string public name = "CrowdFunding Token";
    string public symbol = "CFT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    uint256 public tokenPrice;
    address public owner;
    
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event TokenPriceUpdated(uint256 newPrice);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(uint256 _initialSupply, uint256 _tokenPrice) {
        require(_initialSupply > 0, "Invalid supply");
        require(_tokenPrice > 0, "Invalid price");
        owner = msg.sender;
        totalSupply = _initialSupply * 10**uint256(decimals);
        balances[address(this)] = totalSupply;
        tokenPrice = _tokenPrice;
        emit Transfer(address(0), address(this), totalSupply);
    }
    
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }
    
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balances[msg.sender] >= _value, "Insufficient balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0), "Invalid address");
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balances[_from] >= _value, "Insufficient balance");
        require(allowed[_from][msg.sender] >= _value, "Allowance exceeded");
        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    function buyTokens() public payable returns (uint256) {
        require(msg.value > 0, "Send ETH to buy");
        require(tokenPrice > 0, "Price not set");
        uint256 tokenAmount = (msg.value * 10**uint256(decimals)) / tokenPrice;
        require(tokenAmount > 0, "Amount too small");
        require(balances[address(this)] >= tokenAmount, "Not enough tokens");
        balances[address(this)] -= tokenAmount;
        balances[msg.sender] += tokenAmount;
        emit Transfer(address(this), msg.sender, tokenAmount);
        return tokenAmount;
    }
    
    receive() external payable {
        buyTokens();
    }
    
    function setTokenPrice(uint256 _newPrice) public onlyOwner {
        require(_newPrice > 0, "Invalid price");
        tokenPrice = _newPrice;
        emit TokenPriceUpdated(_newPrice);
    }
    
    function withdrawETH() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH");
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "ETH transfer failed");
    }
}