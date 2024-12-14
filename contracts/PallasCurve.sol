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
    function add(uint x, uint y, uint k) public pure returns (uint256) {
        return addmod(x, y, k);
    }

    function mul(uint x, uint y, uint k) public pure returns (uint256) {
        return mulmod(x, y, k);
    }

    /**
     * @dev Convert affine to projective coordinates
     */
    function toProjective(
        Point memory p
    ) internal pure returns (ProjectivePoint memory) {
        if (p.x == 0 && p.y == 0) {
            return ProjectivePoint(1, 1, 0); // Point at infinity
        }
        return ProjectivePoint(p.x, p.y, 1);
    }

    /**
     * @dev Convert projective to affine coordinates
     */
    function toAffine(
        ProjectivePoint memory p
    ) internal pure returns (Point memory) {
        if (p.z == 0) {
            return Point(0, 0); // Point at infinity
        }

        uint256 zinv = invmod(p.z);
        uint256 zinv_squared = mulmod(zinv, zinv, FIELD_MODULUS);

        return
            Point(
                mulmod(p.x, zinv_squared, FIELD_MODULUS),
                mulmod(
                    p.y,
                    mulmod(zinv, zinv_squared, FIELD_MODULUS),
                    FIELD_MODULUS
                )
            );
    }

    /**
     * @dev Add points in projective coordinates exactly matching o1js
     */
    function projectiveAdd(
        ProjectivePoint memory g,
        ProjectivePoint memory h
    ) internal pure returns (ProjectivePoint memory) {
        if (g.z == 0) return h;
        if (h.z == 0) return g;

        // Z1Z1 = Z1^2
        uint256 Z1Z1 = mulmod(g.z, g.z, FIELD_MODULUS);
        // Z2Z2 = Z2^2
        uint256 Z2Z2 = mulmod(h.z, h.z, FIELD_MODULUS);
        // U1 = X1*Z2Z2
        uint256 U1 = mulmod(g.x, Z2Z2, FIELD_MODULUS);
        // U2 = X2*Z1Z1
        uint256 U2 = mulmod(h.x, Z1Z1, FIELD_MODULUS);
        // S1 = Y1*Z2*Z2Z2
        uint256 S1 = mulmod(
            g.y,
            mulmod(h.z, Z2Z2, FIELD_MODULUS),
            FIELD_MODULUS
        );
        // S2 = Y2*Z1*Z1Z1
        uint256 S2 = mulmod(
            h.y,
            mulmod(g.z, Z1Z1, FIELD_MODULUS),
            FIELD_MODULUS
        );
        // H = U2-U1
        uint256 H = addmod(U2, FIELD_MODULUS - U1, FIELD_MODULUS);

        if (H == 0) {
            if (S1 == S2) {
                return projectiveDouble(g);
            }
            if (addmod(S1, S2, FIELD_MODULUS) == 0) {
                return ProjectivePoint(1, 1, 0); // Point at infinity
            }
            revert("Invalid point addition");
        }

        // I = (2*H)^2
        uint256 I = mulmod(mulmod(H, H, FIELD_MODULUS), 4, FIELD_MODULUS);
        // J = H*I
        uint256 J = mulmod(H, I, FIELD_MODULUS);
        // r = 2*(S2-S1)
        uint256 r = mulmod(
            2,
            addmod(S2, FIELD_MODULUS - S1, FIELD_MODULUS),
            FIELD_MODULUS
        );
        // V = U1*I
        uint256 V = mulmod(U1, I, FIELD_MODULUS);
        // X3 = r^2-J-2*V
        uint256 X3 = addmod(
            mulmod(r, r, FIELD_MODULUS),
            FIELD_MODULUS -
                addmod(J, mulmod(2, V, FIELD_MODULUS), FIELD_MODULUS),
            FIELD_MODULUS
        );
        // Y3 = r*(V-X3)-2*S1*J
        uint256 Y3 = addmod(
            mulmod(
                r,
                addmod(V, FIELD_MODULUS - X3, FIELD_MODULUS),
                FIELD_MODULUS
            ),
            FIELD_MODULUS -
                mulmod(2, mulmod(S1, J, FIELD_MODULUS), FIELD_MODULUS),
            FIELD_MODULUS
        );
        // Z3 = ((Z1+Z2)^2-Z1Z1-Z2Z2)*H
        uint256 Z3 = mulmod(
            addmod(
                mulmod(
                    addmod(g.z, h.z, FIELD_MODULUS),
                    addmod(g.z, h.z, FIELD_MODULUS),
                    FIELD_MODULUS
                ),
                FIELD_MODULUS - addmod(Z1Z1, Z2Z2, FIELD_MODULUS),
                FIELD_MODULUS
            ),
            H,
            FIELD_MODULUS
        );

        return ProjectivePoint(X3, Y3, Z3);
    }

    /**
     * @dev Double point in projective coordinates matching o1js
     */
    function projectiveDouble(
        ProjectivePoint memory g
    ) internal pure returns (ProjectivePoint memory) {
        if (g.z == 0) return g;
        if (g.y == 0) revert("Cannot double point with y=0");

        // A = X1^2
        uint256 A = mulmod(g.x, g.x, FIELD_MODULUS);
        // B = Y1^2
        uint256 B = mulmod(g.y, g.y, FIELD_MODULUS);
        // C = B^2
        uint256 C = mulmod(B, B, FIELD_MODULUS);
        // D = 2*((X1+B)^2-A-C)
        uint256 D = mulmod(
            2,
            addmod(
                mulmod(
                    addmod(g.x, B, FIELD_MODULUS),
                    addmod(g.x, B, FIELD_MODULUS),
                    FIELD_MODULUS
                ),
                FIELD_MODULUS - addmod(A, C, FIELD_MODULUS),
                FIELD_MODULUS
            ),
            FIELD_MODULUS
        );
        // E = 3*A
        uint256 E = mulmod(3, A, FIELD_MODULUS);
        // F = E^2
        uint256 F = mulmod(E, E, FIELD_MODULUS);
        // X3 = F-2*D
        uint256 X3 = addmod(
            F,
            FIELD_MODULUS - mulmod(2, D, FIELD_MODULUS),
            FIELD_MODULUS
        );
        // Y3 = E*(D-X3)-8*C
        uint256 Y3 = addmod(
            mulmod(
                E,
                addmod(D, FIELD_MODULUS - X3, FIELD_MODULUS),
                FIELD_MODULUS
            ),
            FIELD_MODULUS - mulmod(8, C, FIELD_MODULUS),
            FIELD_MODULUS
        );
        // Z3 = 2*Y1*Z1
        uint256 Z3 = mulmod(2, mulmod(g.y, g.z, FIELD_MODULUS), FIELD_MODULUS);

        return ProjectivePoint(X3, Y3, Z3);
    }

    /**
     * @dev Add points in affine coordinates (wrapper around projective)
     */
    function addPoints(
        Point memory p1,
        Point memory p2
    ) public pure returns (Point memory) {
        ProjectivePoint memory g = toProjective(p1);
        ProjectivePoint memory h = toProjective(p2);
        ProjectivePoint memory r = projectiveAdd(g, h);
        return toAffine(r);
    }

    /**
     * @dev Scalar multiplication matching o1js implementation
     */
    function scalarMul(
        Point memory p,
        uint256 scalar
    ) public pure returns (Point memory) {
        ProjectivePoint memory g = toProjective(p);
        ProjectivePoint memory result = ProjectivePoint(1, 1, 0);
        ProjectivePoint memory current = g;

        // scalar = scalar % SCALAR_MODULUS;
        while (scalar > 0) {
            if (scalar & 1 == 1) {
                result = projectiveAdd(result, current);
            }
            current = projectiveDouble(current);
            scalar >>= 1;
        }

        return toAffine(result);
    }

    /**
     * @dev Check if point is on the Pallas curve: y² = x³ + 5
     */
    function isOnCurve(Point memory p) public pure returns (bool) {
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
    ) public pure returns (uint256[] memory) {
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
    ) public pure returns (uint256[] memory) {
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

    uint256 internal constant WINDOW_SIZE = 4;
    uint256 internal constant WINDOW_MASK = (1 << WINDOW_SIZE) - 1;

    /**
     * @dev Modular multiplicative inverse
     */
    function invmod(uint256 a) public pure returns (uint256) {
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

    function sqrtmod(uint256 n, uint256 p) public view returns (uint256) {
        if (n == 0) return 0;

        // Calculate Q and M where p - 1 = Q * 2^M and Q is odd
        uint256 Q = p - 1;
        uint256 M = 0;
        while (Q % 2 == 0) {
            Q /= 2;
            M++;
        }

        // Find a non-residue z
        uint256 z = 2;
        while (true) {
            if (modExp(z, (p - 1) / 2, p) == p - 1) break; // Found a non-residue
            z++;
        }

        uint256 c = modExp(z, Q, p);
        uint256 t = modExp(n, Q >> 1, p); // n^((Q-1)/2)
        uint256 R = mulmod(t, n, p); // n^((Q+1)/2)
        t = mulmod(t, R, p); // n^Q

        while (t != 1) {
            uint256 i = 0;
            uint256 s = t;
            while (s != 1 && i < M) {
                s = mulmod(s, s, p);
                i++;
            }
            require(i < M, "Square root does not exist");

            uint256 b = c;
            for (uint256 j = 0; j < M - i - 1; j++) {
                b = mulmod(b, b, p);
            }
            M = i;
            c = mulmod(b, b, p);
            t = mulmod(t, c, p);
            R = mulmod(R, b, p);
        }

        return R;
    }

    function modExp(
        uint256 base,
        uint256 exponent,
        uint256 modulus
    ) public view returns (uint256 result) {
        assembly {
            // Free memory pointer
            let p := mload(0x40)

            // Store length of base, exponent and modulus
            mstore(p, 0x20)
            mstore(add(p, 0x20), 0x20)
            mstore(add(p, 0x40), 0x20)

            // Store base, exponent and modulus
            mstore(add(p, 0x60), base)
            mstore(add(p, 0x80), exponent)
            mstore(add(p, 0xa0), modulus)

            // Call precompiled contract for modular exponentiation
            if iszero(staticcall(gas(), 0x05, p, 0xc0, p, 0x20)) {
                revert(0, 0)
            }

            result := mload(p)
        }
    }

    function isEven(uint256 x) public pure returns (bool) {
        return (x & 1) == 0;
    }
}
