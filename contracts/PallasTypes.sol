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

    struct Signature {
        uint256 r;
        uint256 s;
    }

    struct ProjectivePoint {
        uint256 x;
        uint256 y;
        uint256 z;
    }
}
