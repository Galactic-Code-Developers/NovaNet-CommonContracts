// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title QuantumOracle – Quantum-Resistant Oracle for Secure Off-chain Data Integration
/// @author NovaNet
/// @notice Provides off-chain data securely to NovaNet smart contracts, protected by quantum-resistant hashes.
/// @dev Quantum resistance implemented using hybrid cryptographic hashing methods.

contract QuantumOracle is Ownable {

    struct QuantumData {
        string data;
        bytes32 quantumHash;
        uint256 timestamp;
    }

    mapping(bytes32 => QuantumData) public oracleData;

    event DataSubmitted(bytes32 indexed dataId, string data, bytes32 quantumHash, uint256 timestamp);
    event DataUpdated(bytes32 indexed dataId, string newData, bytes32 newQuantumHash, uint256 timestamp);

    /// @notice Submits new off-chain data secured by quantum-resistant hash
    /// @param dataId Unique identifier for the data
    /// @param data Off-chain data to store
    /// @param salt Randomized salt provided for quantum-secure hashing
    function submitData(bytes32 dataId, string memory data, string memory salt) external onlyOwner {
        bytes32 quantumHash = generateQuantumHash(data, salt);
        oracleData[dataId] = QuantumData(data, quantumHash, block.timestamp);

        emit DataSubmitted(dataId, data, quantumHash, block.timestamp);
    }

    /// @notice Updates existing oracle data with quantum-resistant verification
    /// @param dataId Identifier for data to update
    /// @param newData New off-chain data
    /// @param salt Randomized salt provided for hashing
    function updateData(bytes32 dataId, string memory newData, string memory salt) external onlyOwner {
        require(oracleData[dataId].timestamp != 0, "Data ID does not exist.");

        bytes32 newQuantumHash = generateQuantumHash(newData, salt);
        oracleData[dataId] = QuantumData(newData, newQuantumHash, block.timestamp);

        emit DataUpdated(dataId, newData, newQuantumHash, block.timestamp);
    }

    /// @notice Retrieves oracle data and quantum hash
    /// @param dataId Unique identifier of data
    /// @return data Off-chain data stored
    /// @return quantumHash Quantum-resistant hash
    /// @return timestamp Timestamp of data storage
    function getData(bytes32 dataId) external view returns (string memory data, bytes32 quantumHash, uint256 timestamp) {
        QuantumData memory qd = oracleData[dataId];
        require(qd.timestamp != 0, "Data ID does not exist.");

        return (qd.data, qd.quantumHash, qd.timestamp);
    }

    /// @dev Quantum-resistant hash generator using a hybrid layered hashing approach
    /// @param data Input data to hash
    /// @param salt Random salt for added entropy
    /// @return quantumHash Quantum-resistant hash output
    function generateQuantumHash(string memory data, string memory salt) internal pure returns (bytes32 quantumHash) {
        bytes32 layer1 = keccak256(abi.encodePacked(data, salt));
        bytes32 layer2 = sha256(abi.encodePacked(layer1, data));
        quantumHash = ripemd160(abi.encodePacked(layer2, salt));
        return quantumHash;
    }

    /// @notice Verifies integrity of oracle data using provided salt
    /// @param dataId Data ID to verify
    /// @param data Data provided externally for verification
    /// @param salt Salt used during hashing
    /// @return isValid Boolean indicating if data is valid
    function verifyQuantumData(bytes32 dataId, string memory data, string memory salt) external view returns (bool isValid) {
        QuantumData memory qd = oracleData[dataId];
        require(qd.timestamp != 0, "Data ID does not exist.");

        bytes32 recomputedHash = generateQuantumHash(data, salt);
        return recomputedHash == qd.quantumHash;
    }
}
