//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Context.sol";
import "./SignValidator.sol";

contract VestingVerify is Context, SignValidator {
    using SafeERC20 for IERC20;

    address private immutable _token;
    uint256 private immutable _cliff;
    uint256 private immutable _maxTokenClaimedAmount;

    mapping(address => bool) private _claimed;

    event Claim(address indexed claimer);

    error ClaimIsNotPossible();
    error CliffPeriodIsNotEnd();

    constructor(address token_, uint256 cliff_, uint256 maxTokenClaimedAmount_) Context(msg.sender) {
        _token = token_;
        _cliff = cliff_;
        _maxTokenClaimedAmount = maxTokenClaimedAmount_;
    }

    function claim(address signer, uint256 amount, uint256 nonce, bytes calldata sign) external {
        address sender = _msgSender();
        if(amount > _maxTokenClaimedAmount)
        {
            revert ClaimIsNotPossible();
        }

        if(_now() <= _cliff) {
            revert CliffPeriodIsNotEnd();
        } 

        if(!_canClaim(sender, signer, amount, nonce, sign)) {
            revert ClaimIsNotPossible();
        }

        _claimed[sender] = true;

        IERC20(_token).transfer(sender, amount);

        emit Claim(sender);
    }

    function checkClaim(address signer, uint256 amount, uint256 nonce, bytes calldata sign) external view returns(bool)
    {
        return _canClaim(_msgSender(), signer, amount, nonce, sign);
    }

    function _canClaim(address claimer, address signer, uint256 amount, uint256 nonce, bytes calldata sign)
        private
        view
        returns (bool)
    {
        return
            !_claimed[claimer] &&
            verify(signer, claimer, amount, nonce, sign);
    }
}