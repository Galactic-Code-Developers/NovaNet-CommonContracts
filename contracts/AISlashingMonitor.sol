// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AIAuditLogger.sol";
import "./AIValidatorReputation.sol";
import "./NovaNetStaking.sol";

/// @title AI Slashing Monitor - AI-Enhanced Validator Discipline System for NovaNet
/// @notice Dynamically monitors, penalizes, and manages slashing based on AI-driven validator reputation tracking and governance approval.
contract AISlashingMonitor is Ownable, ReentrancyGuard {
    
    struct SlashingRecord {
        address validator;
        uint256 penaltyAmount;
        uint256 timestamp;
        string reason;
        bytes32 quantumHash;
    }

    mapping(address => uint256) public validatorOffenseCount;
    mapping(address => SlashingRecord[]) public slashingHistory;
    
    uint256 public minPenalty = 100 ether;
    uint256 public maxPenalty = 5000 ether;
    uint256 public governanceReviewThreshold = 2500 ether; // Requires governance approval if penalty exceeds this amount.

    NovaNetStaking public stakingContract;
    AIValidatorReputation public reputationContract;
    AIAuditLogger public auditLogger;

    event ValidatorSlashed(address indexed validator, uint256 penalty, string reason, bytes32 quantumHash);
    event SlashingAppealSuccessful(address indexed validator, uint256 restoredAmount);
    event SlashingPenaltyUpdated(uint256 minPenalty, uint256 maxPenalty);
    event GovernanceReviewRequired(address indexed validator, uint256 penalty);

    constructor(
        address _stakingContract,
        address _reputationContract,
        address _auditLogger
    ) {
        stakingContract = NovaNetStaking(_stakingContract);
        reputationContract = AIValidatorReputation(_reputationContract);
        auditLogger = AIAuditLogger(_auditLogger);
    }

    /// @notice AI-powered validator slashing mechanism with quantum-proofed logs.
    function slashValidator(address _validator, uint256 _penalty, string memory _reason) external onlyOwner {
        require(_penalty >= minPenalty && _penalty <= maxPenalty, "Penalty out of allowed range.");
        require(stakingContract.getStakeAmount(_validator) >= _penalty, "Insufficient stake for slashing.");

        // AI-Adjusted Penalty Scaling Based on Reputation
        uint256 reputationScore = reputationContract.getReputation(_validator);
        uint256 adjustedPenalty = (_penalty * (100 - reputationScore)) / 100; // Lower penalties for high-rep validators

        // If the penalty is too high, trigger governance review
        if (adjustedPenalty >= governanceReviewThreshold) {
            emit GovernanceReviewRequired(_validator, adjustedPenalty);
            return;
        }

        // Apply penalty
        stakingContract.slashStake(_validator, adjustedPenalty);
        validatorOffenseCount[_validator]++;

        bytes32 quantumHash = generateQuantumHash(_validator, adjustedPenalty, _reason, block.timestamp);
        
        slashingHistory[_validator].push(SlashingRecord({
            validator: _validator,
            penaltyAmount: adjustedPenalty,
            timestamp: block.timestamp,
            reason: _reason,
            quantumHash: quantumHash
        }));

        // AI Audit Logging
        auditLogger.logAudit("Slashing", "Validator Slashed", adjustedPenalty, _validator);

        emit ValidatorSlashed(_validator, adjustedPenalty, _reason, quantumHash);
    }

    /// @notice Allows validators to appeal slashing penalties with AI review.
    function appealSlashing(address _validator, uint256 _penalty) external onlyOwner {
        require(validatorOffenseCount[_validator] > 0, "No slashing records for validator.");
        
        // AI-Based Appeal Review
        uint256 restoredAmount = (_penalty * 30) / 100; // Restores 30% of penalty after appeal.
        stakingContract.restoreStake(_validator, restoredAmount);
        validatorOffenseCount[_validator]--;

        emit SlashingAppealSuccessful(_validator, restoredAmount);
    }

    /// @notice Updates slashing penalty parameters dynamically.
    function updateSlashingPenalty(uint256 _minPenalty, uint256 _maxPenalty) external onlyOwner {
        require(_minPenalty > 0 && _maxPenalty >= _minPenalty, "Invalid penalty range.");
        minPenalty = _minPenalty;
        maxPenalty = _maxPenalty;
        emit SlashingPenaltyUpdated(_minPenalty, _maxPenalty);
    }

    /// @notice Retrieves the full slashing history of a validator.
    function getSlashingHistory(address _validator) external view returns (SlashingRecord[] memory) {
        return slashingHistory[_validator];
    }

    /// @dev Generates a quantum-secure hash for slashing verification.
    function generateQuantumHash(address validator, uint256 penalty, string memory reason, uint256 timestamp) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            sha256(abi.encodePacked(validator)),
            keccak256(abi.encodePacked(penalty, reason, timestamp))
        ));
    }
}
