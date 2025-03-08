// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./AIAuditLogger.sol";
import "./AIGovernanceFraudDetection.sol";
import "./QuantumSecureHasher.sol";
import "./QuantumEntangledBridge.sol";
import "./AIOracleFraudDetection.sol";

contract NovaNetOracle is Ownable, ReentrancyGuard {
    struct DataRequest {
        uint256 requestId;
        address requester;
        string dataQuery;
        string response;
        bool fulfilled;
        uint256 timestamp;
        string quantumSecureHash; // Ensures data integrity
    }

    mapping(uint256 => DataRequest) public dataRequests;
    uint256 public requestCounter;
    mapping(address => bool) public approvedDataProviders;
    uint256 public dataProviderFee = 0.01 ether; // Fee required to submit data

    AIAuditLogger public auditLogger;
    AIGovernanceFraudDetection public fraudDetection;
    QuantumSecureHasher public quantumHasher;
    QuantumEntangledBridge public quantumBridge;
    AIOracleFraudDetection public fraudDetectionOracle;

    event DataRequested(uint256 indexed requestId, address indexed requester, string dataQuery);
    event DataFulfilled(uint256 indexed requestId, address indexed provider, string response, string quantumHash);
    event DataProviderApproved(address indexed provider);
    event DataProviderRemoved(address indexed provider);
    event OracleFeeUpdated(uint256 newFee);
    event OracleFraudDetected(address indexed provider, uint256 fraudScore, string reason);

    constructor(
        address _auditLogger,
        address _fraudDetection,
        address _quantumHasher,
        address _quantumBridge,
        address _fraudDetectionOracle
    ) {
        auditLogger = AIAuditLogger(_auditLogger);
        fraudDetection = AIGovernanceFraudDetection(_fraudDetection);
        quantumHasher = QuantumSecureHasher(_quantumHasher);
        quantumBridge = QuantumEntangledBridge(_quantumBridge);
        fraudDetectionOracle = AIOracleFraudDetection(_fraudDetectionOracle);
    }

    /// @notice Allows users to request off-chain data with AI fraud detection and quantum security.
    function requestData(string memory _query) external payable nonReentrant {
        require(msg.value >= dataProviderFee, "Insufficient fee provided.");
        requestCounter++;

        string memory quantumHash = quantumHasher.generateQuantumHash(msg.sender, msg.value, _query);

        dataRequests[requestCounter] = DataRequest({
            requestId: requestCounter,
            requester: msg.sender,
            dataQuery: _query,
            response: "",
            fulfilled: false,
            timestamp: block.timestamp,
            quantumSecureHash: quantumHash
        });

        emit DataRequested(requestCounter, msg.sender, _query);
    }

    /// @notice Allows approved providers to fulfill a data request with quantum security.
    function fulfillRequest(uint256 _requestId, string memory _response) external nonReentrant {
        require(approvedDataProviders[msg.sender], "Unauthorized data provider.");
        require(dataRequests[_requestId].requestId == _requestId, "Invalid request ID.");
        require(!dataRequests[_requestId].fulfilled, "Request already fulfilled.");

        // AI Fraud Detection
        uint256 fraudScore = fraudDetectionOracle.detectOracleFraud(msg.sender, _response);
        require(fraudScore < 50, "Potential fraud detected! Response rejected.");

        // Quantum Hash Verification for Security
        string memory quantumHash = quantumHasher.generateQuantumHash(msg.sender, fraudScore, _response);

        dataRequests[_requestId].response = _response;
        dataRequests[_requestId].fulfilled = true;
        dataRequests[_requestId].quantumSecureHash = quantumHash;

        // AI Audit Logging for Transparency
        string memory auditEntry = string(
            abi.encodePacked(
                "Oracle Data Request ID: ", uintToString(_requestId),
                " | Provider: ", toAsciiString(msg.sender),
                " | Quantum Hash: ", quantumHash,
                " | Response: ", _response
            )
        );
        auditLogger.logGovernanceAction(_requestId, auditEntry);

        emit DataFulfilled(_requestId, msg.sender, _response, quantumHash);
    }

    /// @notice Approves a new oracle data provider.
    function approveDataProvider(address _provider) external onlyOwner {
        require(!approvedDataProviders[_provider], "Provider already approved.");
        approvedDataProviders[_provider] = true;
        emit DataProviderApproved(_provider);
    }

    /// @notice Removes an oracle data provider.
    function removeDataProvider(address _provider) external onlyOwner {
        require(approvedDataProviders[_provider], "Provider not found.");
        approvedDataProviders[_provider] = false;
        emit DataProviderRemoved(_provider);
    }

    /// @notice Updates the oracle fee for requesting data.
    function updateOracleFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0, "Fee must be greater than zero.");
        dataProviderFee = _newFee;
        emit OracleFeeUpdated(_newFee);
    }

    /// @notice Retrieves a completed oracle response.
    function getOracleResponse(uint256 _requestId) external view returns (string memory) {
        require(dataRequests[_requestId].fulfilled, "Request not yet fulfilled.");
        return dataRequests[_requestId].response;
    }

    /// @notice Converts an address to a string.
    function toAsciiString(address _addr) internal pure returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(_addr);
        bytes memory hexString = new bytes(42);

        hexString[0] = "0";
        hexString[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            bytes1 byteValue = addressBytes[i];
            hexString[2 + (i * 2)] = byteToHexChar(uint8(byteValue) / 16);
            hexString[3 + (i * 2)] = byteToHexChar(uint8(byteValue) % 16);
        }

        return string(hexString);
    }

    /// @notice Converts a byte to a hex character.
    function byteToHexChar(uint8 _byte) internal pure returns (bytes1) {
        if (_byte < 10) {
            return bytes1(uint8(_byte) + 48); // ASCII '0' to '9'
        } else {
            return bytes1(uint8(_byte) + 87); // ASCII 'a' to 'f'
        }
    }

    /// @notice Converts a uint256 to a string.
    function uintToString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) return "0";
        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }
        return string(buffer);
    }
}
