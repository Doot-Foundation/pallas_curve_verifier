// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './PallasConstants.sol';
import './PallasTypes.sol';

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
   * @dev Add two points on the Pallas curve
   */
  function addPoints(
    Point memory p1,
    Point memory p2
  ) internal pure returns (Point memory) {
    if (p1.x == 0 && p1.y == 0) return p2;
    if (p2.x == 0 && p2.y == 0) return p1;

    uint256 slope;
    if (p1.x == p2.x) {
      if (p1.y != p2.y || p1.y == 0) {
        return Point(0, 0);
      }
      // Point doubling slope = (3x²)/(2y)
      uint256 temp = mulmod(
        3,
        mulmod(p1.x, p1.x, FIELD_MODULUS),
        FIELD_MODULUS
      );
      uint256 denom = mulmod(2, p1.y, FIELD_MODULUS);
      uint256 denomInv = invmod(denom, FIELD_MODULUS);
      slope = mulmod(temp, denomInv, FIELD_MODULUS);
    } else {
      // Point addition slope = (y2-y1)/(x2-x1)
      uint256 dx = addmod(p2.x, FIELD_MODULUS - p1.x, FIELD_MODULUS);
      uint256 dy = addmod(p2.y, FIELD_MODULUS - p1.y, FIELD_MODULUS);
      uint256 dxInv = invmod(dx, FIELD_MODULUS);
      slope = mulmod(dy, dxInv, FIELD_MODULUS);
    }

    // x3 = slope² - x1 - x2
    uint256 x3 = addmod(
      mulmod(slope, slope, FIELD_MODULUS),
      FIELD_MODULUS - p1.x - p2.x,
      FIELD_MODULUS
    );

    // y3 = slope(x1 - x3) - y1
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
   * @dev Multiply a point by a scalar using double-and-add
   */
  function scalarMul(
    Point memory p,
    uint256 scalar
  ) internal pure returns (Point memory) {
    Point memory result = Point(0, 0);
    Point memory current = p;

    uint256 s = scalar % SCALAR_MODULUS;

    while (s > 0) {
      if (s & 1 == 1) {
        result = addPoints(result, current);
      }
      current = addPoints(current, current);
      s = s >> 1;
    }

    return result;
  }

  /**
   * @dev Compute modular multiplicative inverse
   */
  function invmod(uint256 a, uint256 m) internal pure returns (uint256) {
    require(a != 0, 'No inverse exists for 0');

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
}
