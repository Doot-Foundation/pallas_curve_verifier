// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    struct SignatureJSON {
        uint256 field;
        uint256 scalar;
    }

    struct Signature {
        uint256 r; // x-coordinate of R
        uint256 s; // scalar value
    }

    struct ProjectivePoint {
        uint256 x;
        uint256 y;
        uint256 z;
    }
}
