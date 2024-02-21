// //SPDX-License-Identifier: MIT
// // Name our invariant
// //what are our invariances int the contract

// //1. the total supply of the dsc should be less than total value colleteral

// //2. our getter view functions should never revert. < evergreen invariant
// pragma solidity ^0.8.19;

// import {Test} from "../../lib/forge-std/src/Test.sol";
// import {console} from "../../lib/forge-std/src/console.sol";
// import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
// import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {helperConfig} from "../../script/helperConfig.s.sol";
// import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {ERC20MockWETH} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

// contract OpenInvaariantTest is StdInvariant, Test {
//     decentralizedStableCoin dsc;
//     DeployDSC deployer;
//     DSCEngine dscEngine;
//     helperConfig config;
//     address wETH;
//     address wBTC;

//     function setUp() public {
//         deployer = new DeployDSC();
//         (dsc, dscEngine, config) = deployer.run();
//         (,, wETH, wBTC,) = config.ActiveNetworkConfig();
//         targetContract(address(dscEngine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         //get the value of the protocol and compare it to the debt of the dsc
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(wETH).balanceOf(address(dscEngine));
//         uint256 totalWbtcDeposited = IERC20(wBTC).balanceOf(address(dscEngine));

//         console.log (totalSupply, " total Supply");
//         console.log (totalWethDeposited, " total weth");
//         console.log (totalWbtcDeposited, " total wbtc");

//         assert(totalWethDeposited + totalWbtcDeposited >= totalSupply);
//     }

//     // getter view function should never revert.
// }
