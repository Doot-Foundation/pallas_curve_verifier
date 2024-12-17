// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./PallasConstants.sol";
import "../PallasTypes.sol";
import "hardhat/console.sol";

/**
 * @title PallasCurve
 * @dev Implementation of Pallas curve operations
 */
contract PallasCurve is PallasTypes {
    /// @notice Field modulus for Pallas curve
    uint256 public constant FIELD_MODULUS =
        0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001;

    /// @notice Scalar field modulus for Pallas curve
    uint256 public constant SCALAR_MODULUS =
        0x40000000000000000000000000224698fc0994a8dd8c46eb2100000001;

    /// @notice Curve equation constant (B) where y² = x³ + B
    uint256 public constant BEQ = 5;

    /// @notice Default signature prefix for testnet
    string public constant SIGNATURE_PREFIX = "CodaSignature*******";

    /// @notice Signature prefix for mainnet
    string public constant MAINNET_SIGNATURE_PREFIX = "MinaSignatureMainnet";

    /// @notice Default length for string operations
    uint256 public constant DEFAULT_STRING_LENGTH = 128;

    /// @notice Generator point x-coordinate
    uint256 public constant G_X = 1;

    /// @notice Generator point y-coordinate
    uint256 public constant G_Y =
        0x1b74b5a30a12937c53dfa9f06378ee548f655bd4333d477119cf7a23caed2abb;

    /// @notice Performs modular addition
    /// @dev Wrapper around Solidity's addmod
    /// @param x First operand
    /// @param y Second operand
    /// @param k Modulus
    /// @return uint256 Result of (x + y) mod k
    function add(uint x, uint y, uint k) internal pure returns (uint256) {
        return addmod(x, y, k);
    }

    /// @notice Performs modular multiplication
    /// @dev Wrapper around Solidity's mulmod
    /// @param x First operand
    /// @param y Second operand
    /// @param k Modulus
    /// @return uint256 Result of (x * y) mod k
    function mul(uint x, uint y, uint k) internal pure returns (uint256) {
        return mulmod(x, y, k);
    }

    /// @notice Computes modular multiplicative inverse
    /// @dev Implements extended Euclidean algorithm for FIELD_MODULUS
    /// @param a Value to invert
    /// @return uint256 Modular multiplicative inverse of a
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

    /// @notice Performs modular exponentiation
    /// @dev Uses precompiled contract at address 0x05
    /// @param base Base value
    /// @param exponent Exponent value
    /// @param modulus Modulus for operation
    /// @return result Result of base^exponent mod modulus
    function modExp(
        uint256 base,
        uint256 exponent,
        uint256 modulus
    ) internal view returns (uint256 result) {
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

    /// @notice Computes modular square root
    /// @dev Implements Tonelli-Shanks algorithm for prime modulus
    /// @param n Value to find square root of
    /// @param p Modulus (must be prime)
    /// @return uint256 Modular square root of n
    function sqrtmod(uint256 n, uint256 p) internal view returns (uint256) {
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

    /// @notice Checks if a number is even
    /// @dev Uses bitwise AND operation
    /// @param x Number to check
    /// @return bool True if number is even
    function isEven(uint256 x) internal pure returns (bool) {
        return (x & 1) == 0;
    }

    /// @notice Converts a point from affine to projective coordinates
    /// @dev Used for efficient point operations. Returns (1:1:0) for point at infinity
    /// @param p Point in affine coordinates (x,y)
    /// @return ProjectivePoint Point in projective coordinates (X:Y:Z)
    function toProjective(
        Point memory p
    ) internal pure returns (ProjectivePoint memory) {
        if (p.x == 0 && p.y == 0) {
            return ProjectivePoint(1, 1, 0); // Point at infinity
        }
        return ProjectivePoint(p.x, p.y, 1);
    }

    /// @notice Converts a point from projective to affine coordinates
    /// @dev Performs modular inverse computation for Z coordinate
    /// @param p Point in projective coordinates (X:Y:Z)
    /// @return Point Point in affine coordinates (x,y)
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

    /// @notice Verifies if a point lies on the Pallas curve
    /// @dev Checks if point satisfies y² = x³ + 5 (Pallas curve equation)
    /// @param p Point to check
    /// @return bool True if point is on curve
    function isOnCurve(Point memory p) internal pure returns (bool) {
        if (p.x >= FIELD_MODULUS || p.y >= FIELD_MODULUS) {
            return false;
        }

        uint256 lhs = mulmod(p.y, p.y, FIELD_MODULUS);
        uint256 x2 = mulmod(p.x, p.x, FIELD_MODULUS);
        uint256 x3 = mulmod(x2, p.x, FIELD_MODULUS);
        uint256 rhs = addmod(x3, BEQ, FIELD_MODULUS);

        return lhs == rhs;
    }

    /// @notice Doubles a point in projective coordinates
    /// @dev Specialized doubling formula for Pallas curve, matching o1js implementation
    /// @param g Point to double in projective coordinates
    /// @return ProjectivePoint Doubled point
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

    /// @notice Adds two points in projective coordinates
    /// @dev Implements complete addition formulas for Pallas curve, matching o1js behavior
    /// @param g First point in projective coordinates
    /// @param h Second point in projective coordinates
    /// @return ProjectivePoint Sum of the points
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

    /// @notice Adds two points in affine coordinates
    /// @dev Converts to projective, adds, then converts back to affine
    /// @param p1 First point in affine coordinates
    /// @param p2 Second point in affine coordinates
    /// @return Point Sum of the points in affine coordinates
    function addPoints(
        Point memory p1,
        Point memory p2
    ) internal pure returns (Point memory) {
        ProjectivePoint memory g = toProjective(p1);
        ProjectivePoint memory h = toProjective(p2);
        ProjectivePoint memory r = projectiveAdd(g, h);
        return toAffine(r);
    }

    /// @notice Performs scalar multiplication of a point
    /// @dev Implements double-and-add algorithm, matching o1js behavior
    /// @param p Base point to multiply
    /// @param scalar Scalar value to multiply by
    /// @return Point Result of scalar multiplication
    function scalarMul(
        Point memory p,
        uint256 scalar
    ) internal pure returns (Point memory) {
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
}
