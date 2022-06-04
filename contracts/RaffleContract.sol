//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import "@chainlink/contracts/src/v0.8/Denominations.sol";
import "./Context.sol";

contract RaffleContract is Context { 
    struct Bet {
        uint256 chance;
        address token;
        address sender;
    }

    Bet[] private _bets;
    uint256 private _totalBets;
    FeedRegistryInterface private _registry;

    constructor(address registry_) Context(msg.sender) {
        _registry = FeedRegistryInterface(registry_);
    }

    function deposit(address token, uint256 amount) external returns(bool) {
        uint256 chance = amount * uint256(_getPrice(token));
        _totalBets += chance;
        _bets.push(Bet({
            chance: chance,
            token: token,
            sender: _msgSender()
        }));
        return true;
    }

    function roll() external returns(bool) {

    }

    function _getPrice(address base) private view returns (int) {
        (
            , 
            int price,
            ,
            ,
            
        ) = _registry.latestRoundData(base, Denominations.ETH);
        return price;
    }

    function _getRundomNumber(uint256 maxNumber) private view returns(uint256) {
        return 0;
    }   
}