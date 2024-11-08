// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './PallasConstants.sol';

/**
 * @title PoseidonT3
 * @dev Implementation of Poseidon hash function for t = 3 (2 inputs)
 */
contract PoseidonT3 is PallasConstants {
  // MDS matrix from o1js constants
  /**
   * @dev Returns MDS matrix values by index
   */
  function getMdsValue(
    uint256 row,
    uint256 col
  ) internal pure returns (uint256) {
    if (row == 0) {
      if (col == 0)
        return
          0x1A8D0E46EE6E2D99236AF46F56D214DD4B782176E7E225AD2628432B15A6D11B;
      if (col == 1)
        return
          0x38053056EAC4A347450E2095D9215B11CFA6BA4E8C5E88575E466D10C176F65D;
      if (col == 2)
        return
          0x3D44CDA730D8D8918F0BB0B5E77FC5862F1E68660F156C434557220DDC4F85A5;
    }
    if (row == 1) {
      if (col == 0)
        return
          0x0A06EDBDD61D53503BC09BF6A34C89799256640731E09D521E02FC8B7E18A46E;
      if (col == 1)
        return
          0x208BED6904F4A8BA92B1613FEF240A4EDF41524C2252E2062213A8B70CF93F8F;
      if (col == 2)
        return
          0x14DEAA2DEB3E710634D0AEB4812C717F1A0CE2CFE1286CF86333E022B1D4189D;
    }
    if (row == 2) {
      if (col == 0)
        return
          0x175CC937FCC193F1117CC4858677C1CF683CA12053304FB27D78B6292011E225;
      if (col == 1)
        return
          0x3CA7F2F9B476069B7F31E31DD2FBDA0EC4C626CD51F5EC1F79269F6876DA7BA7;
      if (col == 2)
        return
          0x3CF3D0D70B812B01BE967353A5E9CFE2D299C1BC38F87E05F2B004C805C06FCC;
    }
    revert('Invalid MDS indices');
  }

  /**
   * @dev Matrix multiplication with MDS matrix
   */
  function mdsMultiply(
    uint256[3] memory state
  ) internal pure returns (uint256[3] memory result) {
    for (uint256 i = 0; i < 3; i++) {
      result[i] = 0;
      for (uint256 j = 0; j < 3; j++) {
        result[i] = addmod(
          result[i],
          mulmod(getMdsValue(i, j), state[j], FIELD_MODULUS),
          FIELD_MODULUS
        );
      }
    }
  }

  /**
   * @dev Initial state array [0, 0, 0]
   */
  function initialState() public pure returns (uint256[3] memory) {
    return [uint256(0), uint256(0), uint256(0)];
  }

  /**
   * @dev Convert prefix string to field element
   */
  function prefixToField(string memory prefix) public pure returns (uint256) {
    bytes memory prefixBytes = bytes(prefix);
    require(prefixBytes.length * 8 < 255, 'prefix too long');

    uint256 result = 0;
    for (uint i = 0; i < prefixBytes.length; i++) {
      uint8 c = uint8(prefixBytes[i]);
      require(c < 128, 'only ASCII characters supported');
      for (uint j = 0; j < 8; j++) {
        result = (result << 1) | (c & 1);
        c = c >> 1;
      }
    }
    return result % FIELD_MODULUS;
  }

  /**
   * @dev Power7 function for Poseidon S-box
   */
  function power7(uint256 x) internal pure returns (uint256) {
    // Calculate x^2
    uint256 x2 = mulmod(x, x, FIELD_MODULUS);
    // Calculate x^3
    uint256 x3 = mulmod(x2, x, FIELD_MODULUS);
    // Calculate x^6 (by squaring x^3)
    uint256 x6 = mulmod(x3, x3, FIELD_MODULUS);
    // Final result: x^7 = x^6 * x
    return mulmod(x6, x, FIELD_MODULUS);
  }

  /**
   * @dev The Poseidon permutation function
   */
  function poseidonPermutation(
    uint256[3] memory state
  ) internal pure returns (uint256[3] memory) {
    for (uint256 r = 0; r < POSEIDON_FULL_ROUNDS; r++) {
      // Apply S-box
      for (uint256 i = 0; i < POSEIDON_STATE_SIZE; i++) {
        state[i] = power7(state[i]);
      }

      // MDS multiplication
      state = mdsMultiply(state);
    }
    return state;
  }

  /**
   * @dev Update state with input
   */
  function update(
    uint256[3] memory state,
    uint256[] memory input
  ) public pure returns (uint256[3] memory) {
    if (input.length == 0) {
      return poseidonPermutation(state);
    }

    uint256 n = ((input.length + POSEIDON_RATE - 1) / POSEIDON_RATE) *
      POSEIDON_RATE;
    for (uint256 blockIndex = 0; blockIndex < n; blockIndex += POSEIDON_RATE) {
      for (
        uint256 i = 0;
        i < POSEIDON_RATE && blockIndex + i < input.length;
        i++
      ) {
        state[i] = addmod(state[i], input[blockIndex + i], FIELD_MODULUS);
      }
      state = poseidonPermutation(state);
    }

    return state;
  }

  /**
   * @dev Hash with prefix exactly as in o1js
   */
  function hashWithPrefix(
    string memory prefix,
    uint256[] memory input
  ) public pure returns (uint256) {
    uint256[3] memory state = initialState();

    uint256[] memory prefixArray = new uint256[](1);
    prefixArray[0] = prefixToField(prefix);
    state = update(state, prefixArray);

    state = update(state, input);

    return state[0];
  }
}
