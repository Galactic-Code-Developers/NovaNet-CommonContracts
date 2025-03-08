// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AIValidatorReputation.sol";
import "./AIAuditLogger.sol";
import "./NovaNetValidator.sol";

/// @title AI Validator Selection - AI-Enhanced Validator Ranking for NovaNet
/// @notice Implements an AI-driven ranking mechanism for validators based on multi-criteria analysis, reputation, and performance tracking.
contract AIValidatorSelection is Ownable, ReentrancyGuard {

    struct ValidatorScore {
        address validator;
        uint256 performanceScore;
        uint256 reputationScore;
        uint256 uptimeScore;
        uint256 stakeWeight;
        uint256 totalScore;
        bytes32 quantumHash;
    }

    mapping(address => uint256) public lastSelectedEpoch;
    mapping(address => bool) public disqualifiedValidators;
    
    uint256 public validatorReputationWeight = 30; // AI-weight for reputation impact
    uint256 public validatorPerformanceWeight = 40; // AI-weight for validator performance
    uint256 public validatorUptimeWeight = 20; // AI-weight for uptime tracking
    uint256 public validatorStakeWeight = 10; // AI-weight for total stake participation
    uint256 public epochInterval = 100; // Blocks per validator rotation

    NovaNetValidator public validatorContract;
    AIValidatorReputation public reputationContract;
    AIAuditLogger public auditLogger;

    event ValidatorRanked(address indexed validator, uint256 totalScore, bytes32 quantumHash);
    event BestValidatorSelected(address indexed bestValidator, uint256 totalScore);
    event ValidatorSelectionParametersUpdated(uint256 reputationWeight, uint256 performanceWeight, uint256 uptimeWeight, uint256 stakeWeight, uint256 epochInterval);

    constructor(
        address _validatorContract,
        address _reputationContract,
        address _auditLogger
    ) {
        validatorContract = NovaNetValidator(_validatorContract);
        reputationContract = AIValidatorReputation(_reputationContract);
        auditLogger = AIAuditLogger(_auditLogger);
    }

    /// @notice AI-driven ranking of validators based on multiple weighted factors.
    function rankValidators() public view returns (ValidatorScore[] memory) {
        address[] memory validators = validatorContract.getActiveValidators();
        ValidatorScore[] memory scores = new ValidatorScore[](validators.length);

        for (uint256 i = 0; i < validators.length; i++) {
            if (disqualifiedValidators[validators[i]]) continue; // Skip disqualified validators

            uint256 performanceScore = validatorContract.getPerformance(validators[i]);
            uint256 reputationScore = reputationContract.getReputation(validators[i]);
            uint256 uptimeScore = validatorContract.getUptime(validators[i]);
            uint256 stakeWeight = validatorContract.getStakeWeight(validators[i]);

            uint256 totalScore = 
                (performanceScore * validatorPerformanceWeight / 100) + 
                (reputationScore * validatorReputationWeight / 100) +
                (uptimeScore * validatorUptimeWeight / 100) +
                (stakeWeight * validatorStakeWeight / 100);

            bytes32 quantumHash = generateQuantumHash(validators[i], totalScore);

            scores[i] = ValidatorScore(validators[i], performanceScore, reputationScore, uptimeScore, stakeWeight, totalScore, quantumHash);
        }

        return scores;
    }

    /// @notice AI-based selection of the best validator, with security verification.
    function selectBestValidator() public returns (address) {
        ValidatorScore[] memory scores = rankValidators();
        address bestValidator = address(0);
        uint256 highestScore = 0;

        for (uint256 i = 0; i < scores.length; i++) {
            if (scores[i].totalScore > highestScore) {
                highestScore = scores[i].totalScore;
                bestValidator = scores[i].validator;
            }
        }

        lastSelectedEpoch[bestValidator] = block.number;

        // AI Audit Logging with quantum security
        auditLogger.logAudit("ValidatorSelection", "New Validator Selected", highestScore, bestValidator);

        emit BestValidatorSelected(bestValidator, highestScore);
        return bestValidator;
    }

    /// @notice AI-based fraud detection to prevent Sybil attacks.
    function detectSybilAttacks(address _validator) external view returns (bool) {
        uint256 linkedAccounts = validatorContract.getLinkedAccounts(_validator);
        return linkedAccounts > 3; // If more than 3 linked accounts, flag as Sybil attempt.
    }

    /// @notice AI-based penalty for validators found engaging in governance fraud.
    function disqualifyValidator(address _validator) external onlyOwner {
        disqualifiedValidators[_validator] = true;
    }

    /// @notice Updates AI-based validator selection parameters dynamically.
    function updateSelectionParameters(
        uint256 _reputationWeight,
        uint256 _performanceWeight,
        uint256 _uptimeWeight,
        uint256 _stakeWeight,
        uint256 _epochInterval
    ) external onlyOwner {
        require(_reputationWeight + _performanceWeight + _uptimeWeight + _stakeWeight == 100, "Weights must total 100%.");
        require(_epochInterval >= 50, "Epoch interval must be at least 50 blocks.");

        validatorReputationWeight = _reputationWeight;
        validatorPerformanceWeight = _performanceWeight;
        validatorUptimeWeight = _uptimeWeight;
        validatorStakeWeight = _stakeWeight;
        epochInterval = _epochInterval;

        emit ValidatorSelectionParametersUpdated(_reputationWeight, _performanceWeight, _uptimeWeight, _stakeWeight, _epochInterval);
    }

    /// @dev Generates a quantum-secure hash for validator selection verification.
    function generateQuantumHash(address validator, uint256 score) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            sha256(abi.encodePacked(validator)),
            keccak256(abi.encodePacked(score))
        ));
    }
}
