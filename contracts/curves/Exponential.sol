// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "../interfaces/IAggregator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Exponential is Ownable {
    uint256 constant public decimals = 10**18;

    IAggregator public ETHDEAIAggregator;
    IAggregator public USDTUSDAggregator;
    IAggregator public STMXUSDAggregator;

    function calculatePrice(
    )   public
        view
        returns (uint256)
    {

        (,int256 resETH,,,) = ETHDEAIAggregator.latestRoundData();
        return resETH;
    }

    /**
     * @dev Owner can set ETH / DEAI Aggregator contract
     * @param _addr Address of aggregator contract
     */
    function setETHDEAIAggregatorContract(address _addr) public onlyOwner {
        ETHDEAIAggregator = IAggregator(address(_addr));
    }

}