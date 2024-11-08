// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './PallasConstants.sol';
import './PallasTypes.sol';
import './PallasCurve.sol';
import './PoseidonT3.sol';

/**
 * @title PallasSignatureVerifier
 * @dev Verifies signatures created using Pallas curve and o1js
 */
contract PallasSignatureVerifier is
  PallasConstants,
  PallasTypes,
  PallasCurve,
  PoseidonT3
{
  /**
   * @dev Verifies a signature against a message and public key
   */
  function verifySignature(
    Signature memory signature,
    Point memory publicKey,
    uint256[] memory message
  ) public pure returns (bool) {
    require(signature.s < SCALAR_MODULUS, 'Invalid s value');
    require(signature.r < FIELD_MODULUS, 'Invalid r value');
    require(isOnCurve(publicKey), 'Public key not on curve');

    // Prepare hash input
    uint256[] memory hashInput = new uint256[](message.length + 3);
    for (uint i = 0; i < message.length; i++) {
      hashInput[i] = message[i];
    }
    hashInput[message.length] = publicKey.x;
    hashInput[message.length + 1] = publicKey.y;
    hashInput[message.length + 2] = signature.r;

    // Compute hash with testnet prefix
    uint256 h = hashWithPrefix(SIGNATURE_PREFIX, hashInput);

    // Compute R = s⋅G - h⋅P
    Point memory hP = scalarMul(publicKey, h);
    Point memory negHp = Point(hP.x, FIELD_MODULUS - hP.y); // Negate y coordinate

    Point memory sG = scalarMul(Point(G_X, G_Y), signature.s);
    Point memory r = addPoints(sG, negHp);

    // Verify r.x equals signature.r and r.y is even
    return r.x == signature.r && r.y % 2 == 0;
  }

  /**
   * @dev Convenience function to verify a signature for a single field element message
   */
  function verifySignatureWithFieldElement(
    Signature memory signature,
    Point memory publicKey,
    uint256 message
  ) public pure returns (bool) {
    uint256[] memory messageArray = new uint256[](1);
    messageArray[0] = message;
    return verifySignature(signature, publicKey, messageArray);
  }

  /**
   * @dev Check if a point is a valid Pallas curve point
   */
  function isValidPublicKey(Point memory point) public pure returns (bool) {
    // Check coordinates are in field
    if (point.x >= FIELD_MODULUS || point.y >= FIELD_MODULUS) {
      return false;
    }

    // Verify y² = x³ + 5
    uint256 lhs = mulmod(point.y, point.y, FIELD_MODULUS);
    uint256 x2 = mulmod(point.x, point.x, FIELD_MODULUS);
    uint256 x3 = mulmod(x2, point.x, FIELD_MODULUS);
    uint256 rhs = addmod(x3, 5, FIELD_MODULUS);

    return lhs == rhs;
  }
}
