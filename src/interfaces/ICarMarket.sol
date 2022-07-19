// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title CarMarket Interface
 * @author Jelo
 * @notice Contains the functions required to purchase a car and withdraw funds from the contract.
 */
interface ICarMarket {
    /**
     * @dev Enables a user to purchase a car
     * @param _color The color of the car to be purchased
     * @param _model The model of the car to be purchased
     * @param _plateNumber The plateNumber of the car to be purchased
     */
    function purchaseCar(
        string memory _color,
        string memory _model,
        string memory _plateNumber
    ) external payable;

    /**
     * @dev Enables the owner of the contract to withdraw funds gotten from the purcahse of a car.
     */
    function withdrawFunds() external;

    function isExistingCustomer(address _customer) external view returns (bool);
}
