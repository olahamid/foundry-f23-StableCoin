//the hadler contract is created to handle the way we make calls from the invariant funzz test
//for example if there is no redeem colateral for the function to redeem any collatral , the handler should protect the fuzz test from over calling the redeemCollatral function
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
import {ERC20MockWETH} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../MOCK/MockV3Aggregator.sol";



//price feed
//with weth
// with wbtc

contract handler is Test {
    DSCEngine dscEngine;
    decentralizedStableCoin dsc;

    ERC20MockWETH wETH;
    ERC20MockWETH wBTC;
    uint public mintIsCalled;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    MockV3Aggregator public ethUSDPriceFeed;

    address[] public a_userWalletThatDeposited;

    constructor(DSCEngine _dscEngine, decentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        wETH = ERC20MockWETH(collateralTokens[0]);
        wBTC = ERC20MockWETH(collateralTokens[1]);
        ethUSDPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wETH)));

        
    }
    //set redeem collatral to be callable when the contract has a collatral
    //the whole idea is to set the depositcollateral up in our handler so the transaction always go through.
    //we do want keep the randomnisation, pick a random collateral to deposit and pick a random amount
    // function mintDSC(uint amount, uint collateralSeed) public {
    //     if (a_userWalletThatDeposited.length == 0) {
    //         return;
    //     }
        
    //     address sender =  a_userWalletThatDeposited[collateralSeed % a_userWalletThatDeposited.length];
    //     (uint256 DSCMinted, uint256 collateralAmountInUSD) = dscEngine.getAccountInformation(sender);
    //     int256 maxDSCToMint = (int256(collateralAmountInUSD) / 2) - (int256(DSCMinted));
    //     if (maxDSCToMint < 0){
    //         return;
    //     }
    //     // amount = bound(amount, 1 , MAX_DEPOSIT_SIZE);
    //     amount = bound(amount, 0 , uint256(maxDSCToMint));

    //     if (amount == 0) {
    //         return;
    //     }
    //     vm.startPrank(sender);
    //     dscEngine.mintDSC(amount);
    //     vm.stopPrank();
    //     mintIsCalled++;
    // }

    function depositCollateral(uint256 collatralSeed, uint256 amountToCollateral) public {
        ERC20MockWETH collateral = _getCollateralFromSeed(collatralSeed);
        amountToCollateral = bound(amountToCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountToCollateral);
        collateral.approve(address(dscEngine), amountToCollateral);

        dscEngine.depositCollateral(address(collateral), amountToCollateral);
        vm.stopPrank();
        a_userWalletThatDeposited.push(msg.sender);
    }

    function redeemCollatral(uint256 collateralSeed, uint256 amountToCollateral) public {
        ERC20MockWETH collateral = _getCollateralFromSeed(collateralSeed);
        uint maxCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountToCollateral = bound(amountToCollateral, 0, maxCollateralToRedeem);
        if (amountToCollateral == 0) {
            return;
        }
        dscEngine.redeemCollateral(address(collateral), amountToCollateral);


    }
    function updateCollateral(uint96 newPrice) public {
        int256  newPriceInt = int256(uint256(newPrice));
        ethUSDPriceFeed.updateAnswer(newPriceInt);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20MockWETH) {
        if (collateralSeed % 2 == 0) {
            return wETH;
        } else {
            return wBTC;
        }
    }
}
