// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PallasTypes
 * @dev Common types used in Pallas operations
 */
contract PallasTypes {
    struct Point {
        uint256 x;
        uint256 y;
    }

    struct PointCompressed {
        uint256 x;
        bool isOdd;
    }

    struct Signature {
        uint256 r;
        uint256 s;
    }

    struct ProjectivePoint {
        uint256 x;
        uint256 y;
        uint256 z;
    }

    struct OptimizedPoint {
        bytes32 x;
        bytes32 y;
    }

    struct OptimizedSignature {
        bytes32 r;
        bytes32 s;
    }

    struct BatchedVerifications {
        bytes32[] fieldsData;
        bytes32[] messageHashes;
        OptimizedSignature[] signatures;
        OptimizedPoint[] keys;
        bool[] isValid;
    }

    // Modified structs with IDs
    struct FieldsVerification {
        uint256 vfId;
        bool isValid;
        uint256[] fields;
        Signature signature;
        Point publicKey;
    }

    struct MessageVerification {
        uint256 vmId;
        bool isValid;
        string message;
        Signature signature;
        Point publicKey;
    }

    struct OptimizedFieldsVerification {
        uint256 vfId;
        bool isValid;
        bytes32[] fields;
        OptimizedSignature signature;
        OptimizedPoint publicKey;
    }

    struct OptimizedMessageVerification {
        uint256 vmId;
        bool isValid;
        bytes32 messageHash;
        OptimizedSignature signature;
        OptimizedPoint publicKey;
    }

    struct OptimizedOriginalMessageVerification {
        uint256 vmId;
        bool isValid;
        OptimizedSignature signature;
        OptimizedPoint publicKey;
        string message;
    }
}
