// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PallasConstants
 * @dev Constants used across Pallas curve operations and Poseidon hashing
 */
contract PallasConstants {
  // Field and curve parameters
  uint256 internal constant FIELD_MODULUS =
    0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001;
  uint256 internal constant SCALAR_MODULUS =
    0x40000000000000000000000000224698fc0994a8dd8c46eb2100000001;

  // curve equation: y² = x³ + 5
  uint256 internal constant B = 5;

  // Generator point from elliptic-curve.js
  uint256 internal constant G_X = 1;
  uint256 internal constant G_Y =
    0x1B7503CCB85A38D6E4987952E639FAE2935AA52872E93B049A62A8B62447640B;

  // Poseidon parameters
  uint256 internal constant POSEIDON_FULL_ROUNDS = 55;
  uint256 internal constant POSEIDON_STATE_SIZE = 3;
  uint256 internal constant POSEIDON_RATE = 2;
  uint256 internal constant POSEIDON_POWER = 7;
  bool internal constant POSEIDON_HAS_INITIAL_ROUND_CONSTANT = false;

  // Signature constants
  string internal constant SIGNATURE_PREFIX = 'CodaSignature*******';
}
