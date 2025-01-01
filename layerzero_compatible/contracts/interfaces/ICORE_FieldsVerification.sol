//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import "../PallasTypes.sol";

struct VerifyFieldsStateCompressed {
    /// @notice Network flag - true for mainnet, false for testnet
    bool mainnet;
    /// @notice Final verification result
    bool isValid;
    /// @notice The public key point (x,y) being verified against
    Point publicKey;
    /// @notice The signature containing r (x-coordinate) and s (scalar)
    Signature signature;
    /// @notice Hash of the fields array with prefix ('e' value)
    uint256 messageHash;
    /// @notice Network-specific prefix for message hashing
    string prefix;
    /// @notice Array of field elements to verify
    uint256[] fields;
}

interface ICORE_FieldsVerification {
    function getVFStateBytesCompressed(uint256 vfId) external view returns (bytes memory);
}
