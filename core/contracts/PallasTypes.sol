// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PallasTypes
 * @dev Common types used in Pallas operations
 */
contract PallasTypes {
    /// @title Point Structure
    /// @notice Represents a point on an elliptic curve with x and y coordinates
    /// @dev Used for public key and signature operations
    struct Point {
        uint256 x;
        uint256 y;
    }

    /// @title Compressed Point Structure
    /// @notice Represents a compressed form of an elliptic curve point
    /// @dev Uses x-coordinate and a boolean flag instead of full coordinates
    struct PointCompressed {
        uint256 x;
        bool isOdd;
    }

    /// @title Digital Signature Structure
    /// @notice Represents a digital signature with its components
    /// @dev Used for cryptographic signature verification
    struct Signature {
        uint256 r;
        uint256 s;
    }

    /// @title Projective Point Structure
    /// @notice Represents a point in projective coordinates
    /// @dev Used for efficient elliptic curve operations
    struct ProjectivePoint {
        uint256 x;
        uint256 y;
        uint256 z;
    }

    /// @title Verify Fields State Structure
    /// @notice Holds the state for field array signature verification process
    /// @dev Used to track the progress and store intermediate results during verification
    struct VerifyFieldsState {
        /// @notice Indicates if the state has been properly initialized
        bool init;
        /// @notice Network flag - true for mainnet, false for testnet
        bool mainnet;
        /// @notice Final verification result
        bool isValid;
        /// @notice Tracks the current step of verification (0-6)
        uint8 atStep;
        /// @notice The public key point (x,y) being verified against
        Point publicKey;
        /// @notice The signature containing r (x-coordinate) and s (scalar)
        Signature signature;
        /// @notice Hash of the fields array with prefix ('e' value)
        uint256 messageHash;
        /// @notice Public key converted to curve point format
        Point pkInGroup;
        /// @notice Result of scalar multiplication s*G
        Point sG;
        /// @notice Result of scalar multiplication e*pkInGroup
        Point ePk;
        /// @notice Final computed point R = sG - ePk
        Point R;
        /// @notice Network-specific prefix for message hashing
        string prefix;
        /// @notice Array of field elements to verify
        uint256[] fields;
    }

    /// @title Verification Fields State Compressed Structure.
    /// @notice Holds only the primary state for message signature verification process
    struct VerifyFieldsStateCompressed {
        /// @notice Indicates the type. 1 for Message, 2 for Fields. Helpful when reading
        uint8 verifyType;
        /// @notice The unique id
        uint256 vfId;
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

    /// @title Verification Message State Structure
    /// @notice Holds the state for message signature verification process
    /// @dev Used to track the progress and store intermediate results during verification
    struct VerifyMessageState {
        /// @notice Indicates if the state has been properly initialized
        bool init;
        /// @notice Network flag - true for mainnet, false for testnet
        bool mainnet;
        /// @notice Final verification result
        bool isValid;
        /// @notice Tracks the current step of verification (0-6)
        uint8 atStep;
        /// @notice The public key point (x,y) being verified against
        Point publicKey;
        /// @notice The signature containing r (x-coordinate) and s (scalar)
        Signature signature;
        /// @notice Stores the computed hash of the message
        uint256 messageHash;
        /// @notice Public key converted to group form
        Point pkInGroup;
        /// @notice Result of scalar multiplication s*G
        Point sG;
        /// @notice Result of scalar multiplication e*pkInGroup
        Point ePk;
        /// @notice Final computed point R = sG - ePk
        Point R;
        /// @notice The message being verified
        string message;
        /// @notice Network-specific prefix for message hashing
        string prefix;
    }

    /// @title Verification Message State Compressed Structure.
    /// @notice Holds only the primary state for message signature verification process
    struct VerifyMessageStateCompressed {
        /// @notice Indicates the type. 1 for Message, 2 for Fields. Helpful when reading
        uint8 verifyType;
        /// @notice The unique id
        uint256 vmId;
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
}
