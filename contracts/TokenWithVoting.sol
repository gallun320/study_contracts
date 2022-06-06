//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./Context.sol";

contract TokenWithVoting is IERC20, IERC20Metadata, Context {

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    

    uint256 private immutable _totalSupply;
    string private _name;
    string private _symbol;

    uint256 private _currentPrice;
    uint256 private _endVotingTime;
    uint256 private _votingPrice;
    uint256 private immutable _duration;
    uint256 private immutable _minVotingStartRequiredAmount;

    mapping(address => mapping(uint256 => uint256)) private _voicesCache;
    mapping(address => mapping(uint256 => uint256)) private _voices;
    uint256 private _yesVoices;
    uint256 private _noVoices;

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
    }

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
        if(block.timestamp < _endVotingTime) revert VotingStillContinue();

        _votingPrice = price_;
        _endVotingTime = block.timestamp + _duration;
        emit StartVoting(_endVotingTime, _votingPrice);
        return true;
    }

    function vote(bool side_) external returns(bool) {
        if(_voices[_msgSender()][_endVotingTime] > 0) revert UserAlreadyVoted();

        uint256 balance = balanceOf(_msgSender());
        uint256 voices = _voicesCache[_msgSender()][_endVotingTime]; 
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
        if(block.timestamp < _endVotingTime && _votingPrice == 0) revert VotingStillContinue();
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

    function sell(uint amount_) external returns(bool) {
        uint256 value = amount_ / _currentPrice;
        uint256 balance = address(this).balance;

        if(value > balance) {
            revert ValueBiggerThanBalance();
        }

        _transfer(_msgSender(), _owner(), amount_);
        payable(_msgSender()).transfer(_currentPrice);

        emit Sell(amount_, value);
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

        if(_votingPrice > 0 && _voicesCache[to][_endVotingTime] == 0)
        {
            _voicesCache[to][_endVotingTime] = amount;
        }

        uint256 fromBalance = _balances[from];
        if(fromBalance < amount) revert OutOfBalance();
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

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