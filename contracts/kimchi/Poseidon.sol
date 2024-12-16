// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PallasConstants.sol";
import "./PallasCurve.sol";
import "hardhat/console.sol";

/**
 * @title PoseidonT3
 * @dev Implementation of Poseidon hash function for t = 3 (2 inputs)
 */
contract Poseidon is PallasCurve, PallasConstants {
    /**
     * @dev Power7 function matching o1js implementation
     */
    function power7(uint256 x) internal pure returns (uint256) {
        uint256 x2 = mulmod(x, x, FIELD_MODULUS);
        uint256 x3 = mulmod(x2, x, FIELD_MODULUS);
        uint256 x6 = mulmod(x3, x3, FIELD_MODULUS);
        return mulmod(x6, x, FIELD_MODULUS);
    }

    function prefixToField(
        string memory prefix
    ) internal pure returns (uint256) {
        bytes memory prefixBytes = bytes(prefix);
        require(prefixBytes.length < 32, "prefix too long");

        uint256 result = 0;
        // Process in little-endian order (like o1js)
        for (uint i = 0; i < 32; i++) {
            if (i < prefixBytes.length) {
                result |= uint256(uint8(prefixBytes[i])) << (i * 8);
            }
        }

        return result % FIELD_MODULUS;
    }

    function stringToField(string memory str) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length < 32, "prefix too long");

        uint256 result = 0;
        // Process in little-endian order (like o1js)
        for (uint i = 0; i < 32; i++) {
            if (i < strBytes.length) {
                result |= uint256(uint8(strBytes[i])) << (i * 8);
            }
            // zeros are handled implicitly
        }

        return result % FIELD_MODULUS;
    }

    /**
     * @dev Returns MDS matrix values by index
     */
    function getMdsValue(
        uint256 row,
        uint256 col
    ) internal view returns (uint256) {
        require(row < 3 && col < 3, "Invalid MDS indices");
        return mdsMatrix[row][col];
    }

    /**
     * @dev Returns round constant for given round and position
     */
    function getRoundConstant(
        uint256 round,
        uint256 pos
    ) internal view returns (uint256) {
        require(
            round < POSEIDON_FULL_ROUNDS && pos < 3,
            "Invalid round constant indices"
        );
        return roundConstants[round][pos];
    }

    /**
     * @dev Matrix multiplication with MDS matrix exactly as in o1js
     */
    function mdsMultiply(
        uint256[3] memory state
    ) internal view returns (uint256[3] memory result) {
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

    function poseidonPermutation(
        uint256[3] memory state
    ) internal view returns (uint256[3] memory) {
        uint256[3] memory currentState = state;

        for (uint256 round = 0; round < POSEIDON_FULL_ROUNDS; round++) {
            // Rest of the permutation logic
            for (uint256 i = 0; i < 3; i++) {
                currentState[i] = power7(currentState[i]);
            }
            currentState = mdsMultiply(currentState);
            for (uint256 i = 0; i < 3; i++) {
                currentState[i] = addmod(
                    currentState[i],
                    getRoundConstant(round, i),
                    FIELD_MODULUS
                );
            }
        }

        return currentState;
    }

    /**
     * @dev Initial state array [0, 0, 0]
     */
    function initialState() internal pure returns (uint256[3] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }

    /**
     * @dev Update state with input
     */
    function update(
        uint256[3] memory state,
        uint256[] memory input
    ) internal view returns (uint256[3] memory) {
        if (input.length == 0) {
            return poseidonPermutation(state);
        }

        // Process exactly POSEIDON_RATE elements at a time
        for (
            uint256 blockIndex = 0;
            blockIndex < input.length;
            blockIndex += POSEIDON_RATE
        ) {
            // Add input to state
            for (
                uint256 i = 0;
                i < POSEIDON_RATE && blockIndex + i < input.length;
                i++
            ) {
                state[i] = addmod(
                    state[i],
                    input[blockIndex + i],
                    FIELD_MODULUS
                );
            }
            state = poseidonPermutation(state);
        }

        return state;
    }

    function poseidonHash(
        uint256[] memory input
    ) public view returns (uint256) {
        uint256[3] memory state = initialState();
        state = update(state, input);

        return state[0];
    }

    function poseidonHashWithPrefix(
        string memory prefix,
        uint256[] memory input
    ) public view returns (uint256) {
        uint256[3] memory state = initialState();

        uint256[] memory prefixArray = new uint256[](1);
        prefixArray[0] = prefixToField(prefix);
        state = update(state, prefixArray);
        state = update(state, input);

        return state[0];
    }
}