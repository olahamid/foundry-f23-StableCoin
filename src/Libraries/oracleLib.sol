//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
* @author:OLA HAMID
* @title: oracleLib 
* @notice: this library is use to check the chainlink oracle for state data

* * If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
 * We want the DSCEngine to freeze if prices become stale.
 *
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol... too bad. 

*/

import {AggregatorV3Interface} from "../../lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV2V3Interface.sol";

library oracleLib{
    error OracleLib_StablePrice();

    uint private constant TIME_OUT = 3 hours;

    function stablePriceCheck(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80) {
        (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  ) = priceFeed.latestRoundData();
  uint sucessScore = block.timestamp - updatedAt;


  if (sucessScore > TIME_OUT) revert OracleLib_StablePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
    
}
