// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IPoolConfiguration.sol";

contract PoolConfiguration is IPoolConfiguration, Ownable, Pausable {
    uint256 interestRate;
    uint256 commitmentFee;
    uint256 commitmentAmountUsdValue;
    uint256 durationOfCommitmentAgreementInDays;
    uint256 upfrontFee;
    uint256 penaltyRate;

    constructor(
        uint256 _interestRate,
        uint256 _commitmentFee,
        uint256 _commitmentAmountUsdValue,
        uint256 _durationOfCommitmentAgreementInDays,
        uint256 _upfrontFee,
        uint256 _penaltyRate
    ) {
        interestRate = _interestRate;
        commitmentFee = _commitmentFee;
        commitmentAmountUsdValue = _commitmentAmountUsdValue;
        durationOfCommitmentAgreementInDays = _durationOfCommitmentAgreementInDays * 1 days; //converts to seconds
        upfrontFee = _upfrontFee;
        penaltyRate = _penaltyRate;
    }

    function getInterestRate() external view returns (uint256) {
        return interestRate;
    }

    function getCommitmentFee() external view returns (uint256) {
        return commitmentFee;
    }

    function getCommitmentAmountUsdValue() external view returns (uint256) {
        return commitmentAmountUsdValue;
    }

    function getDurationOfCommitmentAgreementInDays() external view returns (uint256) {
        return durationOfCommitmentAgreementInDays;
    }

    function getUpfrontFee() external view returns (uint256) {
        return upfrontFee;
    }

    function getPenaltyRate() external view returns (uint256) {
        return penaltyRate;
    }

}
