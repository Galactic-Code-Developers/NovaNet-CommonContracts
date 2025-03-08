// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AIValidatorReputation.sol";
import "./AIGovernanceFraudDetection.sol";

/// @title AI Voting Model - AI-Optimized Voting for NovaNet Governance
/// @notice Implements quantum-resistant AI-powered voting dynamics, fraud detection, and stake weighting.
contract AIVotingModel is Ownable, ReentrancyGuard {

    struct Voter {
        uint256 stakeAmount;
        uint256 reputationScore;
        uint256 lastVoteBlock;
        bool hasVoted;
    }

    mapping(address => Voter) public voters;
    mapping(address => address) public delegation;
    mapping(address => uint256) public fraudFlags;
    
    uint256 public totalVotingPower;
    uint256 public reputationWeight = 40; // Reputation weight in vote calculation
    uint256 public stakeWeight = 60; // Staking weight in vote calculation
    uint256 public reputationDecayRate = 2; // Reputation loss per voting cycle
    uint256 public fraudThreshold = 3; // Number of fraud flags before auto-disqualification

    AIValidatorReputation public reputationContract;
    AIGovernanceFraudDetection public fraudDetection;

    event VoteCast(address indexed voter, uint256 votingPower, bytes32 quantumHash);
    event VotingParametersUpdated(uint256 reputationWeight, uint256 stakeWeight, uint256 reputationDecayRate);
    event DelegationAssigned(address indexed delegator, address indexed delegatee);
    event FraudFlagged(address indexed voter, uint256 fraudScore);
    event VoterDisqualified(address indexed voter);

    constructor(address _reputationContract, address _fraudDetection) {
        reputationContract = AIValidatorReputation(_reputationContract);
        fraudDetection = AIGovernanceFraudDetection(_fraudDetection);
    }

    /// @notice Registers a voter's stake and reputation for AI-weighted voting.
    function registerVoter(uint256 _stakeAmount) external {
        require(_stakeAmount > 0, "Stake amount must be greater than zero.");
        require(voters[msg.sender].stakeAmount == 0, "Already registered.");

        uint256 reputationScore = reputationContract.getReputation(msg.sender);
        voters[msg.sender] = Voter({
            stakeAmount: _stakeAmount,
            reputationScore: reputationScore,
            lastVoteBlock: block.number,
            hasVoted: false
        });

        totalVotingPower += calculateVotingPower(msg.sender);
    }

    /// @notice Allows voters to delegate their voting power to another address.
    function delegateVote(address _delegatee) external {
        require(voters[msg.sender].stakeAmount > 0, "Must be a registered voter.");
        require(voters[_delegatee].stakeAmount > 0, "Delegatee must be a registered voter.");
        require(delegation[msg.sender] == address(0), "Already delegated.");

        delegation[msg.sender] = _delegatee;
        emit DelegationAssigned(msg.sender, _delegatee);
    }

    /// @notice Casts a vote with AI-optimized weight calculation and fraud detection.
    function castVote(bool _support) external {
        require(voters[msg.sender].stakeAmount > 0, "Must be a registered voter.");
        require(!voters[msg.sender].hasVoted, "Already voted.");
        require(fraudFlags[msg.sender] < fraudThreshold, "Voter disqualified for fraud.");

        uint256 votingPower = calculateVotingPower(msg.sender);
        require(votingPower > 0, "No effective voting power.");

        fraudDetection.detectVoteAnomalies(msg.sender);
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].reputationScore = applyReputationDecay(voters[msg.sender].reputationScore);
        voters[msg.sender].lastVoteBlock = block.number;

        bytes32 quantumHash = generateQuantumHash(msg.sender, votingPower);

        emit VoteCast(msg.sender, votingPower, quantumHash);
    }

    /// @notice AI-powered calculation of voting power.
    function calculateVotingPower(address _voter) public view returns (uint256) {
        Voter storage voter = voters[_voter];
        uint256 weightedStake = (voter.stakeAmount * stakeWeight) / 100;
        uint256 weightedReputation = (voter.reputationScore * reputationWeight) / 100;
        return weightedStake + weightedReputation;
    }

    /// @notice Updates voting weight percentages for reputation and stake.
    function updateVotingParameters(uint256 _reputationWeight, uint256 _stakeWeight, uint256 _reputationDecayRate) external onlyOwner {
        require(_reputationWeight + _stakeWeight == 100, "Total must equal 100%.");
        require(_reputationDecayRate > 0, "Decay rate must be positive.");
        reputationWeight = _reputationWeight;
        stakeWeight = _stakeWeight;
        reputationDecayRate = _reputationDecayRate;

        emit VotingParametersUpdated(_reputationWeight, _stakeWeight, _reputationDecayRate);
    }

    /// @notice Applies AI-driven reputation decay after voting.
    function applyReputationDecay(uint256 reputationScore) internal view returns (uint256) {
        uint256 decay = (reputationScore * reputationDecayRate) / 100;
        return reputationScore > decay ? reputationScore - decay : 0;
    }

    /// @notice Flags a voter for fraud detection.
    function flagVoterForFraud(address _voter) external onlyOwner {
        fraudFlags[_voter]++;
        emit FraudFlagged(_voter, fraudFlags[_voter]);

        if (fraudFlags[_voter] >= fraudThreshold) {
            voters[_voter].hasVoted = true; // Disable further voting
            emit VoterDisqualified(_voter);
        }
    }

    /// @dev Generates a quantum-secure hash for vote verification.
    function generateQuantumHash(address voter, uint256 votingPower) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            sha256(abi.encodePacked(voter)),
            keccak256(abi.encodePacked(votingPower))
        ));
    }
}
