//SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "../test/MOCK/MockV3Aggregator.sol";
import {ERC20MockWETH} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract helperConfig is Script {
    //we are doing this on the sapolia network firstly
    struct NetworkConfig {
        address wETHUSDPriceFeedAddress;
        address wBTCUSDPriceFeedAddress;
        address wETH;
        address wBTC;
        uint256 deployer_key;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    NetworkConfig public ActiveNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            ActiveNetworkConfig = getSapoliaETHConfig();
        } else {
            ActiveNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSapoliaETHConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wETHUSDPriceFeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTCUSDPriceFeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployer_key: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (ActiveNetworkConfig.wETHUSDPriceFeedAddress != address(0)) {
            return ActiveNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUSDPricefeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        ERC20MockWETH ETHMock = new ERC20MockWETH(msg.sender);

        //BTCA
        MockV3Aggregator btcUSDPricefeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20MockWETH BTCMock = new ERC20MockWETH(msg.sender);
        vm.stopBroadcast();

        return NetworkConfig({
            wETHUSDPriceFeedAddress: address(ethUSDPricefeed),
            wBTCUSDPriceFeedAddress: address(btcUSDPricefeed),
            wETH: address(ETHMock),
            wBTC: address(BTCMock),
            deployer_key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
    }
}
