// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "src/Hackable.sol";

contract HackableTest is BaseTest {
    hackable private hackableContract;

    constructor() {
        string[] memory userLabels = new string[](1);
        userLabels[0] = "Player";
        preSetUp(1, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        hackableContract = hackable(payable(0x445D0FA7FA12A85b30525568DFD09C3002F2ADe5));
        vm.label(address(hackableContract), "Hackable");

        assertEq(hackableContract.done(), false);
    }

    function testTransferEDTToken() public {
        address player = users[0];

        // This challenge is quite easy to find a solution
        // The boring part is to call the `cantCallMe` function in the right moment in time...
        // Let's see why

        // If you look at the `cantCallMe` function to solve the challenge it requires that
        // `block.number % mod` is equal to `lastXDigits`
        // Looking at the value of those two state variables (those are public but you could read the slot directly via Foundry cheatcodes)
        //
        // lastXDigits  -> 45
        // mod          -> 100
        // This mean that whatevery `block.number % 100 == 45`
        // This will happens when the last two digits of the `block.number` are equal to `45`
        // So the challenge is solvable ONLY at a specific block.number and if you miss it you need to wait 100 blocks.
        // More or less it take 15 seconds to mint a block so if you missed the opportunity you would have to wait 25 minutes

        // Random block number just to test the solution
        uint256 solutionBlockNumber = 948574245;

        // warp the blockchain to the blocknumber that will solve the challenge
        vm.roll(solutionBlockNumber);

        // Assert that the solution is correct
        assertEq(solutionBlockNumber % hackableContract.mod(), hackableContract.lastXDigits());

        // Solve the challenge
        vm.prank(player);
        hackableContract.cantCallMe();

        // assert it has been solved
        assertEq(hackableContract.winner(), player);
        assertEq(hackableContract.done(), true);
    }
}
