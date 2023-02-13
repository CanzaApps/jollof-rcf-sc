// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPool {
    function distributor() external view returns (uint256);
}