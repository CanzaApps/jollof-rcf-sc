// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPoolConfiguration {
    function getInterestRate() external view returns (uint256);
    function getCommitmentFee() external view returns (uint256);
    function getCommitmentAmountUsdValue() external view returns (uint256);
    function getDurationOfCommitmentAgreementInDays() external view returns (uint256);
    function getUpfrontFee() external view returns (uint256);
}