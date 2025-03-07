// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AIGovernanceFraudDetection.sol";

contract AIExecutionFilter is Ownable {
    AIGovernanceFraudDetection public fraudDetection;

    uint256 public minimumAIScore = 70;

    event ExecutionAllowed(uint256 proposalId, uint256 aiScore);
    event ExecutionBlocked(uint256 proposalId, uint256 aiScore, string reason);

    constructor(address _fraudDetectionContract) {
        fraudDetection = AIGovernanceFraudDetection(_fraudDetectionContract);
    }

    /// @notice Determines if a governance proposal meets AI criteria for execution
    function checkExecution(uint256 proposalId, uint256 aiScore) external returns (bool) {
        bool isFraudulent = fraudDetection.isProposalFraudulent(proposalId);

        if (isFraudulent || aiScore < minimumAIScore) {
            emit ExecutionBlocked(proposalId, aiScore);
            return false;
        }

        emit ExecutionAllowed(proposalId, aiScore);
        return true;
    }

    /// @notice Updates the minimum AI score required for execution
    function setMinimumAIScore(uint256 _newScore) external onlyOwner {
        require(_newScore <= 100, "AI Score cannot exceed 100");
        minimumAIScore = _newScore;
    }
}
