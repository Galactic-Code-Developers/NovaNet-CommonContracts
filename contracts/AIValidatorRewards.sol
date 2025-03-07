// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title AIValidatorRewards - AI-Optimized Validator Reward Distribution for NovaNet
/// @notice Automates validator rewards using AI-driven scoring for fairness, performance, and reputation tracking.
contract AIValidatorRewards is Ownable, ReentrancyGuard {

    struct Validator {
        uint256 stakeAmount;
        uint256 performanceScore;
        uint256 reputationScore;
        uint256 lastClaimedEpoch;
    }

    mapping(address => Validator) public validators;
    address[] public validatorList;

    uint256 public totalRewardPool;
    uint256 public currentEpoch;
    uint256 public epochDuration = 6500; // Approx. 1 day at 13s block time

    // AI Scoring Weights (percentage-based)
    uint256 public performanceWeight = 50;
    uint256 public reputationWeight = 50;

    event ValidatorRewarded(address indexed validator, uint256 reward, uint256 epoch);
    event ValidatorRegistered(address indexed validator, uint256 stakeAmount);
    event EpochAdvanced(uint256 newEpoch);
    event RewardPoolFunded(uint256 amount);

    /// @notice Registers or updates validator information
    function registerValidator(address _validator, uint256 _stakeAmount, uint256 _performanceScore, uint256 _reputationScore) external onlyOwner {
        require(_validator != address(0), "Invalid validator address");
        if (validators[_validator].stakeAmount == 0) {
            validatorList.push(_validator);
        }
        validators[_validator] = Validator(_stakeAmount, _performanceScore, _reputationScore, currentEpoch);
        emit ValidatorRegistered(_validator, _stakeAmount);
    }

    /// @notice Advances the epoch manually (should be automated via cron/keeper)
    function advanceEpoch() external onlyOwner {
        currentEpoch += 1;
        emit EpochAdvanced(currentEpoch);
    }

    /// @notice Funds the reward pool from external sources (e.g., treasury)
    function fundRewardPool() external payable onlyOwner {
        require(msg.value > 0, "Must fund with a positive amount");
        totalRewardPool += msg.value;
        emit RewardPoolFunded(msg.value);
    }

    /// @notice Calculates total score using AI-driven weights
    function calculateAIScore(address validator) internal view returns (uint256) {
        Validator memory val = validators[validator];
        return ((val.performanceScore * performanceWeight) / 100) + ((val.reputationScore * reputationWeight) / 100);
    }

    /// @notice Distributes rewards to all validators based on AI-driven scores
    function distributeRewards() external onlyOwner nonReentrant {
        require(totalRewardPool > 0, "No rewards to distribute");

        uint256 totalScore;
        for (uint256 i = 0; i < validatorList.length; i++) {
            totalScore += calculateAIScore(validatorList[i]);
        }

        require(totalScore > 0, "Total validator score is zero");

        for (uint256 i = 0; i < validatorList.length; i++) {
            address validator = validatorList[i];
            uint256 validatorScore = calculateAIScore(validator);
            uint256 reward = (totalRewardPool * validatorScore) / totalScore;

            validators[validator].lastClaimedEpoch = currentEpoch;
            payable(validator).transfer(reward);
            emit ValidatorRewarded(validator, reward, currentEpoch);
        }

        totalRewardPool = 0; // Reset reward pool after distribution
    }

    /// @notice Sets new AI scoring weights
    function setScoringWeights(uint256 _performanceWeight, uint256 _reputationWeight) external onlyOwner {
        require(_performanceWeight + _reputationWeight == 100, "Weights must total 100");
        performanceWeight = _performanceWeight;
        reputationWeight = _reputationWeight;
    }

    /// @notice Gets validator details
    function getValidatorDetails(address validator) external view returns (Validator memory) {
        return validators[validator];
    }

    /// @notice Retrieves all registered validators
    function getAllValidators() external view returns (address[] memory) {
        return validatorList;
    }
}
