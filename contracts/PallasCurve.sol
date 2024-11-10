// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PallasConstants.sol";
import "./PallasTypes.sol";
import "hardhat/console.sol";

/**
 * @title PallasCurve
 * @dev Implementation of Pallas curve operations
 */
contract PallasCurve is PallasConstants, PallasTypes {
    /**
     * @dev Check if point is on the Pallas curve: y² = x³ + 5
     */
    function isOnCurve(Point memory p) internal pure returns (bool) {
        if (p.x >= FIELD_MODULUS || p.y >= FIELD_MODULUS) {
            return false;
        }

        uint256 lhs = mulmod(p.y, p.y, FIELD_MODULUS);
        uint256 x2 = mulmod(p.x, p.x, FIELD_MODULUS);
        uint256 x3 = mulmod(x2, p.x, FIELD_MODULUS);
        uint256 rhs = addmod(x3, B, FIELD_MODULUS);

        return lhs == rhs;
    }

    /**
     * @dev Convert string directly to fields without bit conversion
     */
    function stringToFields(
        string calldata str
    ) internal pure returns (uint256[] memory) {
        bytes memory strBytes = bytes(str);
        uint256 numFields = (strBytes.length + 31) / 32; // 32 bytes per field
        uint256[] memory fields = new uint256[](numFields);

        for (uint256 i = 0; i < numFields; i++) {
            uint256 field = 0;
            for (uint256 j = 0; j < 32 && (i * 32 + j) < strBytes.length; j++) {
                field |= uint256(uint8(strBytes[i * 32 + j])) << (j * 8);
            }
            fields[i] = field % FIELD_MODULUS;
        }

        return fields;
    }

    /**
     * @dev Optimized helper function to convert bits to field elements
     */
    function bitsToFields(
        uint256[] memory words,
        uint256 totalBits
    ) internal pure returns (uint256[] memory) {
        uint256 numFields = (totalBits + 254) / 255;
        uint256[] memory fields = new uint256[](numFields);

        uint256 currentWord = 0;
        uint256 bitsInCurrentWord = 0;
        uint256 currentField = 0;
        uint256 bitsInCurrentField = 0;

        for (uint256 i = 0; i < totalBits; i++) {
            // Get next bit
            if (bitsInCurrentWord == 0) {
                currentWord = words[i / 256];
                bitsInCurrentWord = 256;
            }
            uint256 bit = currentWord & 1;
            currentWord >>= 1;
            bitsInCurrentWord--;

            // Add bit to current field
            currentField |= bit << bitsInCurrentField;
            bitsInCurrentField++;

            // If field is full, store it
            if (bitsInCurrentField == 255) {
                fields[i / 255] = currentField;
                currentField = 0;
                bitsInCurrentField = 0;
            }
        }

        // Store last partial field if any
        if (bitsInCurrentField > 0) {
            fields[numFields - 1] = currentField;
        }

        return fields;
    }

    /**
     * @dev Compute modular multiplicative inverse
     */
    function invmod(uint256 a, uint256 m) internal pure returns (uint256) {
        require(a != 0, "No inverse exists for 0");

        int256 t1;
        int256 t2 = 1;
        uint256 r1 = m;
        uint256 r2 = a;
        uint256 q;

        while (r2 != 0) {
            q = r1 / r2;
            (t1, t2) = (t2, t1 - int256(q) * t2);
            (r1, r2) = (r2, r1 - q * r2);
        }

        if (t1 < 0) t1 += int256(m);
        return uint256(t1);
    }

    uint256 internal constant WINDOW_SIZE = 4;
    uint256 internal constant WINDOW_MASK = (1 << WINDOW_SIZE) - 1;

    function scalarMul(
        Point memory p,
        uint256 scalar
    ) internal view returns (Point memory) {
        console.log("Starting optimized scalar multiplication...");

        Point memory result = Point(0, 0);
        scalar = scalar % SCALAR_MODULUS;

        if (scalar == 0) {
            return result;
        }

        // Precompute small multiples
        Point[16] memory precomp;
        precomp[0] = Point(0, 0);
        precomp[1] = p;
        for (uint i = 2; i < (1 << WINDOW_SIZE); i++) {
            precomp[i] = addPoints(precomp[i - 1], p);
        }

        // Process 4 bits at a time
        for (uint i = 0; i <= 252; i += WINDOW_SIZE) {
            // Double WINDOW_SIZE times
            for (uint j = 0; j < WINDOW_SIZE; j++) {
                result = addPoints(result, result);
            }

            // Add precomputed value
            uint256 window = (scalar >> i) & WINDOW_MASK;
            if (window > 0) {
                result = addPoints(result, precomp[window]);
            }

            if (i % 32 == 0) {
                console.log("Processing bit:", i);
            }
        }

        console.log("Scalar multiplication completed");
        return result;
    }

    function addPoints(
        Point memory p1,
        Point memory p2
    ) internal pure returns (Point memory) {
        // If either point is zero, return the other point
        if (p1.x == 0 && p1.y == 0) return p2;
        if (p2.x == 0 && p2.y == 0) return p1;

        uint256 slope;
        if (p1.x == p2.x) {
            // Point doubling
            if (p1.y != p2.y || p1.y == 0) {
                return Point(0, 0);
            }
            // Optimized slope calculation for doubling
            uint256 x_squared = mulmod(p1.x, p1.x, FIELD_MODULUS);
            uint256 numerator = mulmod(3, x_squared, FIELD_MODULUS);
            uint256 denominator = mulmod(2, p1.y, FIELD_MODULUS);
            slope = mulmod(
                numerator,
                invmod(denominator, FIELD_MODULUS),
                FIELD_MODULUS
            );
        } else {
            // Point addition
            uint256 dx = addmod(p2.x, FIELD_MODULUS - p1.x, FIELD_MODULUS);
            uint256 dy = addmod(p2.y, FIELD_MODULUS - p1.y, FIELD_MODULUS);
            slope = mulmod(dy, invmod(dx, FIELD_MODULUS), FIELD_MODULUS);
        }

        // Compute x3
        uint256 x3 = addmod(
            mulmod(slope, slope, FIELD_MODULUS),
            addmod(FIELD_MODULUS - p1.x, FIELD_MODULUS - p2.x, FIELD_MODULUS),
            FIELD_MODULUS
        );

        // Compute y3
        uint256 y3 = addmod(
            mulmod(
                slope,
                addmod(p1.x, FIELD_MODULUS - x3, FIELD_MODULUS),
                FIELD_MODULUS
            ),
            FIELD_MODULUS - p1.y,
            FIELD_MODULUS
        );

        return Point(x3, y3);
    }

    /**
     * @dev Modular multiplicative inverse
     */
    function invmod(uint256 a) internal pure returns (uint256) {
        require(a != 0, "Cannot invert 0");

        int256 t = 0;
        int256 newt = 1;
        int256 r = int256(FIELD_MODULUS);
        int256 newr = int256(a);
        uint256 q;

        while (newr != 0) {
            q = uint256(r / newr);
            (t, newt) = (newt, t - int256(q) * newt);
            (r, newr) = (newr, r - int256(q) * newr);
        }

        if (t < 0) t += int256(FIELD_MODULUS);
        return uint256(t);
    }
}
