//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {decentralizedStableCoin} from "../../src/decentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    decentralizedStableCoin dsc;

    function setUp() public {
        dsc = new decentralizedStableCoin();
    }

    function testDSCMustMintMoreThanZero() public {
        vm.startPrank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(this), 0);
        vm.stopPrank();
    }

    function testMustBurnMoreThanZero() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(this), 100);
        vm.expectRevert();
        dsc.burn(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanYouHave() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(this), 100);
        vm.expectRevert();
        dsc.burn(101);
        vm.stopPrank();
    }

    function testCantMintToZeroAddress() public {
        vm.startPrank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(0), 100);
        vm.stopPrank();
    }
}
