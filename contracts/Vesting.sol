//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Context.sol";

contract Vesting is Context {
    using SafeERC20 for IERC20;

    address private immutable _token;
    bytes32 private immutable _merkleRoot;
    uint256 private immutable _cliff;
    uint256 private immutable _tokenClaimedAmount;

    mapping(address => bool) private _claimed;

    event Claim(address indexed claimer);

    error ClaimIsNotPossible();
    error CliffPeriodIsNotEnd();

    constructor(address token_, bytes32 merkelRoot_, uint256 cliff_, uint256 tokenClaimedAmount_) Context(msg.sender) {
        _token = token_;
        _merkleRoot = merkelRoot_;
        _cliff = cliff_;
        _tokenClaimedAmount = tokenClaimedAmount_;
    }

    function claim(bytes32[] calldata merkleProof) external {
        address sender = _msgSender();
        if(_now() <= _cliff) {
            revert CliffPeriodIsNotEnd();
        } 

        if(!_canClaim(sender, merkleProof)) {
            revert ClaimIsNotPossible();
        }

        _claimed[sender] = true;

        IERC20(_token).transfer(sender, _tokenClaimedAmount);

        emit Claim(sender);
    }

    function checkClaim(bytes32[] calldata merkleProof) external view returns(bool)
    {
        return _canClaim(_msgSender(), merkleProof);
    }

    function _canClaim(address claimer, bytes32[] calldata merkleProof)
        private
        view
        returns (bool)
    {
        return
            !_claimed[claimer] &&
            MerkleProof.verify(
                merkleProof,
                _merkleRoot,
                keccak256(abi.encodePacked(claimer))
            );
    }
}