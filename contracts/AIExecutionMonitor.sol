// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AIAuditLogger.sol";

contract AIExecutionMonitor is Ownable {
    AIAuditLogger public auditLogger;

    struct ExecutionRecord {
        uint256 proposalId;
        uint256 aiScore;
        bool executed;
        uint256 timestamp;
    }

    mapping(uint256 => ExecutionLog) public executionLogs;

    event ExecutionRecorded(uint256 indexed proposalId, uint256 aiScore, bool executed);

    constructor(address _auditLogger) {
        auditLogger = AIAuditLogger(_auditLogger);
    }

    /// @notice Logs the execution of governance proposals
    function logExecution(uint256 proposalId, uint256 aiScore, bool executed) external onlyOwner {
        string memory action = executed ? "Proposal Executed" : "Execution Rejected";
        auditLogger.logAudit(action, aiScore, msg.sender);

        executionLogs[proposalId] = ExecutionLog(block.timestamp, aiScore, executed);
        emit ExecutionLogged(proposalId, aiScore, executed);
    }

    /// @notice Retrieves execution logs for proposals
    function getExecutionLog(uint256 proposalId) external view returns (uint256, uint256, bool) {
        ExecutionLog memory log = executionLogs[proposalId];
        return (log.timestamp, log.aiScore, log.executed);
    }

    /// @notice Struct to hold proposal execution log details
    struct ExecutionLog {
        uint256 timestamp;
        uint256 aiScore;
        bool executed;
    }
}
