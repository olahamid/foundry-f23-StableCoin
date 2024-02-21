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

pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DSCEngine} from "./DSCEngine.sol";

/*
* @title DecentralisedStableCoin
* @author Ola Hamid
* Collateral: exogenous 
* Minting: Alogirithm
* Ralative Stability: pegged to USD
* this is the conttract meant to be governed by DSCEngine. this contract is just the ERC20
implementation system
* 
*/

contract decentralizedStableCoin is ERC20Burnable, Ownable {
    error DSC_MustBeMoreThanZero();
    error DSC_BurnAmountExceed();
    error DSC_NotZeroAddress();

    constructor() ERC20("decentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    //burn
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DSC_MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DSC_BurnAmountExceed();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DSC_NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DSC_MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
