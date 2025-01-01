//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import "../PallasTypes.sol";

struct VerifyMessageStateCompressed {
    /// @notice Network flag - true for mainnet, false for testnet
    bool mainnet;
    /// @notice Final verification result
    bool isValid;
    /// @notice The public key point (x,y) being verified against
    Point publicKey;
    /// @notice The signature containing r (x-coordinate) and s (scalar)
    Signature signature;
    /// @notice Stores the computed hash of the message
    uint256 messageHash;
    /// @notice Network-specific prefix for message hashing
    string prefix;
    /// @notice The message being verified
    string message;
}

interface ICORE_MessageVerification {
    function getVMStateBytesCompressed(uint256 vmId) external view returns (bytes memory);
}
