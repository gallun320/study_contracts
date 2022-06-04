//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

abstract contract Context {
    address private immutable _ownerAddr;

    constructor(address owner_) {
        _ownerAddr = owner_;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgValue() internal view virtual returns (uint256) {
        return msg.value;
    }

    function _owner() internal view virtual returns (address) {
        return _ownerAddr;
    }

    function _now() internal view virtual returns(uint256) {
        return block.timestamp;
    }
}