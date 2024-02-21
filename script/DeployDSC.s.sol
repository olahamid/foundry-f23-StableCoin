//SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {decentralizedStableCoin} from "../src/decentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {helperConfig} from "./helperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    helperConfig HelperConfig;

    function run() external returns (decentralizedStableCoin, DSCEngine, helperConfig) {
        HelperConfig = new helperConfig();

        (
            address wETHUSDPriceFeedAddress,
            address wBTCUSDPriceFeedAddress,
            address wETH,
            address wBTC,
            uint256 deployer_key
        ) = HelperConfig.ActiveNetworkConfig();

        tokenAddresses = [wETH, wBTC];
        priceFeedAddresses = [wETHUSDPriceFeedAddress, wBTCUSDPriceFeedAddress];
        vm.startBroadcast(deployer_key);
        decentralizedStableCoin dsc = new decentralizedStableCoin();
        DSCEngine Engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc)); //you need to create helperconfig to sort out the parameter
        dsc.transferOwnership(address(Engine));
        vm.stopBroadcast();
        return (dsc, Engine, HelperConfig);
    }
}
