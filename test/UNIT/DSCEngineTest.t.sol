//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";
import {helperConfig} from "../../script/helperConfig.s.sol";
import {ERC20ForceApproveMock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20ForceApproveMock.sol";
import {ERC20MockWETH} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    helperConfig Config;
    decentralizedStableCoin dsc;
    address wETHUSDPriceFeedAddress;
    address wBTCUSDPriceFeedAddress;
    address wETH;
    address wBTC;
    uint256 public AMOUNT_TO_SPEND = 10 ether;
    uint256 amountToMint = 100 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    address public USER = makeAddr("user");

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, Config) = deployer.run();
        (wETHUSDPriceFeedAddress, wBTCUSDPriceFeedAddress, wETH, wBTC,) = Config.ActiveNetworkConfig();
        // Mint the required amount of WETH to the user's account
        ERC20MockWETH(wETH).mint(USER, AMOUNT_TO_SPEND);
    }
    ////////////////////
    ///constructor test//
    ///////////////////

    address[] public tokenAddresses;
    address[] public priceFeedsAddresses;

    function testRevertIfTokenLengthDoesNotMatch() public {
        tokenAddresses.push(wETH);
        priceFeedsAddresses.push(wETHUSDPriceFeedAddress);
        priceFeedsAddresses.push(wBTCUSDPriceFeedAddress);

        vm.expectRevert(DSCEngine.DSCEngne_addressMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedsAddresses, address(dsc));
    }

    function testgetUSDValue() public {
        uint256 ETHprice = 15e18;
        uint256 expectedValue = 30000e18;

        uint256 actualValue = dscEngine.getUSDValue(wETH, ETHprice);
        assertEq(expectedValue, actualValue);
    }

    function testgetTokenAmountFromUSD() public {
        uint256 USDAmount = 200 ether;
        uint256 expectedValue = 0.1 ether;
        uint256 actualValue = dscEngine.getTokenAmountFromUSD(USDAmount, wETH);
        assertEq(expectedValue, actualValue);
    }
    //depositCollateral Functions

    function testRevertIfCollateralZERO() public {
        //prank a user
        vm.startPrank(USER);
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND);
        vm.expectRevert(DSCEngine.DSCEngine_needMoreThanZero.selector);
        dscEngine.depositCollateral(wETH, 0);
        vm.stopPrank();
    }
    // function testRevertWithUnapprovedCollateral() public {
    //     ERC20MockWETH ranToken = new ERC20MockWETH (USER);
    //     vm.startPrank(USER);
    //     vm.expectRevert(DSCEngine.DSCEngine_collateralNotDeposited.selector);
    //     dscEngine.depositCollateral(address(ranToken), 100e10);
    //     vm.stopPrank();
    // }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND);
        dscEngine.depositCollateral(wETH, AMOUNT_TO_SPEND);
        vm.stopPrank();
        _;
    }
    

    function testCandepositAndGetAccountInformation() public depositedCollateral {
        (uint256 DSCMinted, uint256 collateralAmountInUSD) = dscEngine.getAccountInformation(USER);

        uint256 expectedTokedDSCMinted = 0;
        uint256 expectedCollateralAmountInUSD = dscEngine.getTokenAmountFromUSD(collateralAmountInUSD, wETH);

        assertEq(DSCMinted, expectedTokedDSCMinted);
        assertEq(AMOUNT_TO_SPEND, expectedCollateralAmountInUSD);
    }

    function testMintDSCWithoutModifier() public {
        // Prank the user to simulate their actions
        vm.startPrank(USER);
        ERC20MockWETH(wETH).mint(USER, AMOUNT_TO_SPEND);
        // Approve the DSCEngine contract to spend the user's WETH tokens
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND);

        // Deposit the collateral
        dscEngine.depositCollateral(wETH, AMOUNT_TO_SPEND);

        // Specify the amount of DSC tokens to mint
        uint256 amountToMint = 1 ether;

        // Retrieve the initial balance of DSC tokens for the user
        uint256 initialDSCBalance = dsc.balanceOf(USER);

        // Call the mintDSC function to mint the specified amount of DSC tokens
        dscEngine.mintDSC(amountToMint);

        // Check the new balance of DSC tokens for the user
        uint256 newDSCBalance = dsc.balanceOf(USER);
        vm.stopPrank();
        // Assert that the DSC balance has increased by the minted amount
        assertEq(newDSCBalance, initialDSCBalance + amountToMint, "DSC balance did not increase correctly");

        
    }

    function testRevertWithUnapprovedCollateral() public {
        // Step  1: Create a new mock ERC20 token for collateral
        ERC20MockWETH mockToken = new ERC20MockWETH(USER);
        // Step  2: Start a prank on the USER address to simulate user actions
        vm.startPrank(USER);
        // Step  3: Attempt to call depositCollateral without approving the contract
        // We expect this to revert because the contract has not been approved to spend the user's tokens
        vm.expectRevert(DSCEngine.DSCEngine_collateralNotDeposited.selector);
        dscEngine.depositCollateral(address(mockToken), 100e10);
        // Step  4: Stop the prank after the test
        vm.stopPrank();
    }

    function testConstructorInitialization() public {
        // Arrange
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = wETH;
        tokenAddresses[1] = wBTC;

        address[] memory priceFeedsAddresses = new address[](2);
        priceFeedsAddresses[0] = wETHUSDPriceFeedAddress;
        priceFeedsAddresses[1] = wBTCUSDPriceFeedAddress;

        // Act
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedsAddresses, address(dsc));

        // Assert
        assertTrue(engine.m_priceFeeds(wETH) == wETHUSDPriceFeedAddress, "WETH price feed not set correctly");
        assertTrue(engine.m_priceFeeds(wBTC) == wBTCUSDPriceFeedAddress, "WBTC price feed not set correctly");
        assertTrue(engine.a_tokenAddresses(0) == wETH, "First token address not set correctly");
        assertTrue(engine.a_tokenAddresses(1) == wBTC, "Second token address not set correctly");
    }

    function testDepositCollateral() public {
        //arrange
        uint256 depositAmount = 1 ether;
        vm.startPrank(USER);
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), depositAmount);// Approve the DSCEngine contract to spend the user's tokens
        ERC20MockWETH(wETH).mint(USER, depositAmount); // Mint tokens to the user's address
        

        // Check that the user's balance is sufficient before attempting to deposit collateral
        uint256 userBalance = ERC20ForceApproveMock(wETH).balanceOf(USER);
        vm.stopPrank();

        console.log ("userbalaance:", userBalance);
        console.log("deposit amount", depositAmount);

        assertEq(userBalance, (depositAmount + AMOUNT_TO_SPEND), "User's balance is not sufficient for deposit");

        //act
        //   dscEngine.depositCollateral(wETH, depositAmount);
        //   //assert
        //   uint depositedAmount = dscEngine.m_collateralsDeposited(USER, wETH);
        //   console.log(depositAmount);
        //   console.log(depositedAmount);
        //   assertEq(depositedAmount, depositAmount);
        // assertTrue(dscEngine.a_tokenAddresses(0) == wETH, "Token address not found in the list of deposited tokens");
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = dscEngine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }

    function testGetDsc() public {
        address dscAddress = dscEngine.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(USER);
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND);
        dscEngine.depositCollateral(wETH, AMOUNT_TO_SPEND);
        vm.stopPrank();
        uint256 collateralValue = dscEngine.getAccountCollateraledAmount(USER);
        uint256 expectedCollateralValue = dscEngine.getUSDValue(wETH, AMOUNT_TO_SPEND);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(USER);
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND);
        dscEngine.depositCollateral(wETH, AMOUNT_TO_SPEND);
        vm.stopPrank();
        uint256 collateralBalance = dscEngine.getCollateralBalanceOfUser(USER, wETH);
        assertEq(collateralBalance, AMOUNT_TO_SPEND);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = dscEngine.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = dscEngine.getAccountInformation(USER);
        uint256 expectedCollateralValue = dscEngine.getUSDValue(wETH, AMOUNT_TO_SPEND);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(USER);
        ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND);
        dscEngine.depositCollateralAndMintDSC(wETH, AMOUNT_TO_SPEND, amountToMint);
        dsc.approve(address(dscEngine), amountToMint);
        
        dscEngine.redeemCollateraForDSC(wETH, AMOUNT_TO_SPEND, amountToMint);
        
        // dscEngine.redeemCollateral(wETH, AMOUNT_TO_SPEND);
        // dscEngine.burnDSC(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }
    // function testRedeemCollateral() public {
    // // Arrange
    // // uint256 depositAmount =  1  ether;
    // uint256 mintAmount =  100  ether;
    // uint256 redeemAmount =  1  ether;

    //  // Ensure the user has enough collateral and DSC tokens
    // ERC20ForceApproveMock(wETH).mint(USER, AMOUNT_TO_SPEND);
    // ERC20ForceApproveMock(wETH).approve(address(dscEngine), AMOUNT_TO_SPEND );
    // dscEngine.depositCollateral(wETH, AMOUNT_TO_SPEND);
    // dscEngine.mintDSC(mintAmount);

    // //ACT
    // //start a prank to simulate the user's action 
    // vm.startPrank(USER);
    // dscEngine.redeemCollateral(wETH, redeemAmount);
    // vm.stopPrank();

    // //assert
    // uint finalCollateralBalance = ERC20ForceApproveMock(wETH).balanceOf(USER);
    // uint suspectBalance = (AMOUNT_TO_SPEND - redeemAmount);
    // console.log ("final Balance:", finalCollateralBalance);
    // console.log ("suspected Balance:", suspectBalance);
    // assertEq(finalCollateralBalance, suspectBalance);




    // }
}
