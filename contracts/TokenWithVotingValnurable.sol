//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./Context.sol";
import "hardhat/console.sol";

contract TokenWithVotingValnurable is IERC20, IERC20Metadata, Context {

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    

    uint256 internal immutable _totalSupply;
    string internal _name;
    string internal _symbol;

    uint256 internal _currentPrice;
    uint256 internal _endVotingTime;
    uint256 internal _votingPrice;
    uint256 internal immutable _duration;
    uint256 internal immutable _minVotingStartRequiredAmount;

    mapping(address => mapping(uint256 => uint256)) internal _voicesCache;
    mapping(address => mapping(uint256 => uint256)) internal _voices;
    mapping(address => mapping(bytes32 => uint256)) internal _transfers;
    uint256 internal _yesVoices;
    uint256 internal _noVoices;

    address[] internal _blacklist;

    error ZeroAddress();
    error OutOfBalance();
    error UnderRequiredBalance();
    error VotingStillContinue();
    error UserAlreadyVoted();
    error UserValueUnderThePrice();
    error ValueBiggerThanBalance();

    event StartVoting(uint256 duration, uint256 price);
    event Vote(bool side, uint256 voice);
    event EndVoting(uint256 price);
    event Buy(uint256 amount, uint256 price);
    event Sell(uint256 amount, uint256 price);

    constructor(uint256 totalSupply_, uint256 duration_) Context(msg.sender) {
        _name = "TEST";
        _symbol = "TST";
        _duration = duration_;
        _totalSupply = totalSupply_;
        _minVotingStartRequiredAmount = (5 * _totalSupply) / 100;
        _currentPrice = 1 wei;
        _balances[msg.sender] = totalSupply_;
    }

    receive() external payable {}

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function votingPrice() external view returns(uint256) {
        return _votingPrice;
    }

    function votingEndTime() external view returns(uint256) {
        return _endVotingTime;
    }

    function currentPrice() external view returns(uint256) {
        return _currentPrice;
    }

    function startVoting(uint256 price_) external returns(bool) {
        uint256 balance = balanceOf(_msgSender());

        if(balance < _minVotingStartRequiredAmount) revert UnderRequiredBalance();

        _votingPrice = price_;
        _endVotingTime = block.timestamp + _duration;
        emit StartVoting(_endVotingTime, _votingPrice);
        return true;
    }

    function vote(bool side_) external returns(bool) {
        if(_voices[_msgSender()][_endVotingTime] > 0) revert UserAlreadyVoted();

        uint256 balance = balanceOf(_msgSender());
        uint256 voices = _voices[_msgSender()][_endVotingTime]; 
        if(voices > 0)
        {
            balance = voices;
        }

        _voices[_msgSender()][_endVotingTime] = balance;
        if(side_)
        {
            _yesVoices += balance;
            emit Vote(side_, balance);
            return true;
        }
        
        _noVoices += balance;
        emit Vote(side_, balance);
        return true;
    }

    function endVoting() external returns(bool) {
        uint256 balance = balanceOf(_msgSender());
        if(balance < _minVotingStartRequiredAmount) revert UnderRequiredBalance();
        if(_yesVoices > _noVoices)
        {
            _currentPrice = _votingPrice;
        }
        _votingPrice = 0;
        _yesVoices = 0;
        _noVoices = 0;
        emit EndVoting(_currentPrice);
        return true;
    }

    function buy(uint amount_) external payable returns(bool) {
        uint256 value = _msgValue();
        if(!_compareNotionals(value, _currentPrice, amount_)) {
            revert UserValueUnderThePrice();
        }

        _transfer(_owner(), _msgSender(), amount_);
        emit Buy(amount_, _currentPrice);
        return true;
    }

    function sell(uint256 amount_) external returns(bool) {
        uint256 value = amount_ * _currentPrice;
        uint256 balance = address(this).balance;
        console.log("Balance ", balance, value);
        (bool success, ) = _msgSender().call{value: value}("");
        require(success);

        _balances[_owner()] += amount_;

        emit Sell(amount_, _currentPrice);
        return true;
    }

    function _compareNotionals(uint256 outPrice, uint256 inPrice, uint256 amount) internal pure returns(bool) {
        uint256 inNotional = inPrice * amount;
        return inNotional == outPrice;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if(from == address(0)) revert ZeroAddress();
        if(to == address(0)) revert ZeroAddress();

        for(uint256 i = 0; i < _blacklist.length; i++) {
            if(_blacklist[i] == from) {
                revert("To much transfers");
            }
        }

        uint256 fromBalance = _balances[from];
        if(fromBalance < amount) revert OutOfBalance();

        if(_transfers[from][blockhash(block.number - 2)] > 0 &&
            _transfers[from][blockhash(block.number - 1)] > 0 &&
            _transfers[from][blockhash(block.number)] > 0
        )
        {
            _blacklist.push(from);
        }

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        _transfers[from][blockhash(block.number)] = _balances[from];

        emit Transfer(from, to, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        if(owner == address(0)) revert ZeroAddress();
        if(spender == address(0)) revert ZeroAddress();

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if(currentAllowance < amount) revert OutOfBalance();
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}