//SPDX-Licence-Identifier: MIT
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/*
* @title DecentralisedStableCoin
* @author Ola Hamid
* Aboout it is similar to DAI, without a governance in fees and it's only backed by wETH and wBTC
 The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
*/
pragma solidity ^0.8.19;
/////////////////////
/// IMPORT //////////
/////////////////////

import {decentralizedStableCoin} from "../src/decentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV2V3Interface.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {oracleLib} from "../src/Libraries/oracleLib.sol";

contract DSCEngine is ReentrancyGuard {
    using Math for uint256;
    using oracleLib for AggregatorV3Interface;
    /////////////////////
    /// error //
    /////////////////

    error DSCEngine_needMoreThanZero();
    error DSCEngne_addressMustBeSameLength();
    error DSCEngine_allowedToken();
    error DSCEngine_collateralNotDeposited();
    error DSCEngine_TransferFailed();
    error DSC_BreaksHealthFactor(uint256 HealthFACTOR);
    error DSC_errorHealthFactorOk();
    error DSCEngine_HeathNotImproved();
    error DSCEngine_UnderflowError();
    ///
    error DSC_MintFailed();

    /////////////////////
    /// modifier //
    //////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine_needMoreThanZero();
        }
        _;
    }

    modifier allowedToken(address allowedAddr) {
        if (allowedAddr == address(0)) {
            revert DSCEngine_allowedToken();
        }
        _;
    }
    /////////////////////
    /// S_VARIABLES and MAPS //
    /////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THREESHOLD = 50; //200% OVER COLLATRAL
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LiquationBonus = 10;

    mapping(address token => address priceFeed) public m_priceFeeds;
    //to track the amount of collaterals that a user is using
    mapping(address users => mapping(address token => uint256 amount)) public m_collateralsDeposited;
    mapping(address users => uint256 amount) private m_DSCMinted;
    //ARRAY//
    ///////////
    address[] public a_tokenAddresses;
    //Immutable State Variables
    decentralizedStableCoin private immutable i_dsc;
    /////////////////////
    /// EVENT //
    /////////////////

    event CollateralsDeposited(address indexed usersAddress, address indexed tokenAddress, uint256 indexed amount);
    event e_CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeemTo,
        address indexed tokencollateralAddress,
        uint256 amountCollateral
    );

    /////////////////////
    ///external function //
    /////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedsAddresses, address DSCAddresses) {
        if (tokenAddresses.length != priceFeedsAddresses.length) {
            revert DSCEngne_addressMustBeSameLength();
        }
        //loop through the token address
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            m_priceFeeds[tokenAddresses[i]] = priceFeedsAddresses[i];
            //so basically this looping os saying that if your token havve price feed they are allowed if they dont have a price feed they are nt allowed
            i_dsc = decentralizedStableCoin(DSCAddresses);
            a_tokenAddresses.push(tokenAddresses[i]);
        }
    }
    /////////////////////
    /// Extrnal Function //
    /////////////////

    // function depositAndMintDSC() external {}

    // function getHealthFactor() public view returns(uint) {
    //     _healthFactor(msg.sender);

    // }
    /*
     * @notice Follow CEI in your functions
     * @notice in other to mint DSC, you need to check the collateral value > DSC amount.
     * @notice it will involve checking pricefeed and value 
     * @notice they have more collateral value than the minimum threeshold
     *  @notice there should be a threshold used to be set to keep the collateral to never be less than the DSC
     *  */

    function depositCollateral(address tokenCollateralsAddress, uint256 amountCollected)
        public
        moreThanZero(amountCollected)
        allowedToken(tokenCollateralsAddress)
        nonReentrant
    {
        m_collateralsDeposited[msg.sender][tokenCollateralsAddress] += amountCollected;
        emit CollateralsDeposited(msg.sender, tokenCollateralsAddress, amountCollected);
        bool success = IERC20(tokenCollateralsAddress).transferFrom(msg.sender, address(this), amountCollected);
        if (!success) {
            revert DSCEngine_collateralNotDeposited();
        }
    }

    function mintDSC(uint256 amountToMint) public moreThanZero(amountToMint) {
        m_DSCMinted[msg.sender] += amountToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool Minted = i_dsc.mint(msg.sender, amountToMint);
        if (!Minted) {
            revert DSC_MintFailed();
        }
    }
    //this functionn will allow user deposit and mint at the same time

    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }
    // in order to redeem collaterral, there health factor musst be more than 1
    // dry dont repeat yourself
    // CEI cheacks Effects Interactionn
    //for the to able to redeem thier tokenn they need to be able to get theier DSC back as well, hence the burndsc function has to be implemented

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
        moreThanZero(amountCollateral)
        // nonReentrant
    {
        //     m_collateralsDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        //     emit e_CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);
        //     //calc the health factor
        //     bool success = IERC20(msg.sender). transfer(msg.sender, amountCollateral);
        //     //transfer is when you transsfer from yourself while trasferfrom isn when you transfer from someone else
        //     if (!success) {
        //         revert DSCEngine_TransferFailed();
        //     }
         m_collateralsDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit e_CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFailed();

        }
    
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function _burnDSC(address onBehalfOf, address DSCFrom, uint256 amountToBurn) private {
        //if they(user) feels that they have too many of DSC and need more collateral, burn function helps them
        m_DSCMinted[onBehalfOf] -= amountToBurn;
        bool success = i_dsc.transferFrom(DSCFrom, address(this), amountToBurn);
        if (!success) {
            revert DSCEngine_TransferFailed();
        }
        i_dsc.burn(amountToBurn);
    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {
        // balance = balance.sub(amount);
        //if they(user) feels that they have too many of DSC and need more collateral, burn function helps them
        _burnDSC(msg.sender, msg.sender, amount);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateraForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountToBurn)
        public
    {
        burnDSC(amountToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }
    //this function allow any user to call someone that has health factor to be set as poor
    //if someone is under collateralized we will pay you to liquidate them
    //$75 of eth backing $50 DSC
    //liquidator takes $75 backing and burnsoff/ pays off the $50 DSC

    function liquidate(address collateral, address user, uint256 amountToCover)
        external
        moreThanZero(amountToCover)
        nonReentrant
    {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor <= MIN_HEALTH_FACTOR) {
            revert DSC_errorHealthFactorOk();
        }
        //We want to burn their DSC "debt amount"
        //and take thier collateral
        //and user: 140 eth, 100 dsc
        //liquidate $100 eth, 100 dsc
        // debtToCover = $100
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(amountToCover, collateral);
        // we are giving giving the liquadator a 10% bonus, we are givning 110 dollars of weth for 100 DSC
        // so we should implement a feature to liquidate in the event of the protocol
        uint256 bonusCollateral = ((tokenAmountFromDebtCovered * LiquationBonus) / 100);
        uint256 totalCollateralToRedeem = (bonusCollateral + tokenAmountFromDebtCovered);
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnDSC(collateral, user, amountToCover);

        uint256 endUserHealthFactor = _healthFactor(user);
        if (endUserHealthFactor <= startingHealthFactor) {
            revert DSCEngine_HeathNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function getTokenAmountFromUSD(uint256 usdamountinWei, address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(m_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //10e18 * 1e18 / 2000e8 * 1e10
        return (usdamountinWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /////////////////////
    /// internal and private function //
    /////////////////
    /*
    * @notice what this does is that it returs how close to liqution the user is
    * @notice if the user goes below 1, they can get liquidated 
    */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 DSCMinted, uint256 collateralAmountInUSD)
    {
        DSCMinted = m_DSCMinted[user];
        collateralAmountInUSD = getAccountCollateraledAmount(user);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 DSCMinted, uint256 collateralAmountInUSD)
    {
        (DSCMinted, collateralAmountInUSD) = _getAccountInformation(user);
    }

    function _healthFactor(address user) public view returns (uint256) {
        //to create the health factor you need to get the DSC minted and the
        //total colllateral value
        //making sure the collateral value is > the DSC minted

        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
        // return (collateralValueInUSD / totalDSCMinted);
        uint256 adjucstedValueForThreeshold = (collateralValueInUSD * LIQUIDATION_THREESHOLD) / LIQUIDATION_PRECISION;
        return (adjucstedValueForThreeshold * PRECISION) / totalDSCMinted;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        //1 check the health factor (do they have enouggh collateral?)
        // 2. revert if they dont
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSC_BreaksHealthFactor(userHealthFactor);
        }
    }

    function getAccountCollateraledAmount(address user) public view returns (uint256 totalCollateralValueInUSD) {
        //loop through each collateral token, get the amount they have deposited from a mapping uisng an ARRAY
        for (uint256 i = 0; i < a_tokenAddresses.length; i++) {
            address token = a_tokenAddresses[i];
            uint256 amount = m_collateralsDeposited[user][token];
            totalCollateralValueInUSD += getUSDValue(token, amount);
        }
        return totalCollateralValueInUSD;
    }
    //for getting price feed of the token in USD using aggregatorV3interface

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(m_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.stablePriceCheck();
        //the retuning vale from CL will be 1e18
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return m_collateralsDeposited[user][token];
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THREESHOLD;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return a_tokenAddresses;
    }
    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return m_priceFeeds[token];
    }
}
