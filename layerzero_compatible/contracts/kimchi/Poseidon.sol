// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PallasConstants.sol";
import "./PallasCurve.sol";

/**
 * @title PoseidonT3
 * @dev Implementation of Poseidon hash function for t = 3 (2 inputs)
 */
contract Poseidon is PallasCurve, PallasConstants {
    uint256 internal constant CODA_PREFIX_FIELD = 240717916736854602989207148466022993262069182275;
    uint256 internal constant MINA_PREFIX_FIELD = 664504924603203994814403132056773144791042910541;

    /// @notice Computes x^7 mod FIELD_MODULUS
    /// @dev Optimized power7 implementation matching o1js
    /// @param x Base value
    /// @return uint256 Result of x^7 mod FIELD_MODULUS
    function power7(uint256 x) internal pure returns (uint256) {
        uint256 x2 = mulmod(x, x, FIELD_MODULUS);
        uint256 x3 = mulmod(x2, x, FIELD_MODULUS);
        uint256 x6 = mulmod(x3, x3, FIELD_MODULUS);
        return mulmod(x6, x, FIELD_MODULUS);
    }

    // Matrix and Round Constants
    /// @notice Retrieves value from MDS matrix at specified position
    /// @dev Used in the Poseidon permutation
    /// @param row Row index of MDS matrix
    /// @param col Column index of MDS matrix
    /// @return uint256 Value at specified position
    function getMdsValue(uint256 row, uint256 col) internal view returns (uint256) {
        require(row < 3 && col < 3, "Invalid MDS indices");
        return mdsMatrix[row][col];
    }

    /// @notice Retrieves round constant for specified round and position
    /// @dev Used in the Poseidon permutation
    /// @param round Round number
    /// @param pos Position within the round
    /// @return uint256 Round constant value
    function getRoundConstant(uint256 round, uint256 pos) internal view returns (uint256) {
        require(round < POSEIDON_FULL_ROUNDS && pos < 3, "Invalid round constant indices");
        return roundConstants[round][pos];
    }

    /// @notice Performs matrix multiplication with MDS matrix
    /// @dev Exactly matches o1js implementation
    /// @param state Current state array
    /// @return result Result of matrix multiplication
    function mdsMultiply(uint256[3] memory state) internal view returns (uint256[3] memory result) {
        result[0] = addmod(
            addmod(
                mulmod(getMdsValue(0, 0), state[0], FIELD_MODULUS),
                mulmod(getMdsValue(0, 1), state[1], FIELD_MODULUS),
                FIELD_MODULUS
            ),
            mulmod(getMdsValue(0, 2), state[2], FIELD_MODULUS),
            FIELD_MODULUS
        );

        result[1] = addmod(
            addmod(
                mulmod(getMdsValue(1, 0), state[0], FIELD_MODULUS),
                mulmod(getMdsValue(1, 1), state[1], FIELD_MODULUS),
                FIELD_MODULUS
            ),
            mulmod(getMdsValue(1, 2), state[2], FIELD_MODULUS),
            FIELD_MODULUS
        );

        result[2] = addmod(
            addmod(
                mulmod(getMdsValue(2, 0), state[0], FIELD_MODULUS),
                mulmod(getMdsValue(2, 1), state[1], FIELD_MODULUS),
                FIELD_MODULUS
            ),
            mulmod(getMdsValue(2, 2), state[2], FIELD_MODULUS),
            FIELD_MODULUS
        );
    }

    // State Management
    /// @notice Creates initial state array [0, 0, 0]
    /// @dev Used to initialize Poseidon hash state
    /// @return uint256[3] Initial state array
    function initialState() internal pure returns (uint256[3] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }

    /// @notice Performs the Poseidon permutation on a state
    /// @dev Core permutation function for Poseidon hash
    /// @param state Input state array
    /// @return uint256[3] Permuted state
    function poseidonPermutation(uint256[3] memory state) internal view returns (uint256[3] memory) {
        for (uint256 round = 0; round < POSEIDON_FULL_ROUNDS; round++) {
            state[0] = power7(state[0]);
            state[1] = power7(state[1]);
            state[2] = power7(state[2]);

            state = mdsMultiply(state);

            state[0] = addmod(state[0], getRoundConstant(round, 0), FIELD_MODULUS);
            state[1] = addmod(state[1], getRoundConstant(round, 1), FIELD_MODULUS);
            state[2] = addmod(state[2], getRoundConstant(round, 2), FIELD_MODULUS);
        }
        return state;
    }

    /// @notice Updates state with input values
    /// @dev Processes input in blocks of POSEIDON_RATE size
    /// @param state Current state array
    /// @param input Input values to process
    /// @return uint256[3] Updated state
    function update(uint256[3] memory state, uint256[] memory input) internal view returns (uint256[3] memory) {
        if (input.length == 0) {
            return poseidonPermutation(state);
        }

        uint256 blockIndex;
        while (blockIndex < input.length) {
            // Unrolled POSEIDON_RATE loop for common case of rate=2
            if (blockIndex < input.length) {
                state[0] = addmod(state[0], input[blockIndex], FIELD_MODULUS);
            }
            if (blockIndex + 1 < input.length) {
                state[1] = addmod(state[1], input[blockIndex + 1], FIELD_MODULUS);
            }

            state = poseidonPermutation(state);
            blockIndex += POSEIDON_RATE;
        }

        return state;
    }

    /// String/Field Conversions
    /// @notice Converts a string prefix to a field element
    /// @dev Processes bytes in little-endian order, matching o1js implementation
    /// @param prefix The string to convert
    /// @return uint256 Field element representation of the prefix
    function prefixToField(string memory prefix) internal pure returns (uint256) {
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

    /// @notice Converts a string to a field element
    /// @dev Processes bytes in little-endian order, similar to prefixToField
    /// @param str The string to convert
    /// @return uint256 Field element representation of the string
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

    // Main Hashing Functions
    /// @notice Computes Poseidon hash of input array
    /// @dev Main hashing function without prefix
    /// @param input Array of field elements to hash
    /// @return uint256 Resulting hash
    function poseidonHash(uint256[] memory input) public view returns (uint256) {
        uint256[3] memory state = initialState();
        state = update(state, input);

        return state[0];
    }

    /// @notice Computes Poseidon hash with prefix
    /// @dev Hashes prefix followed by input array
    /// @param prefix String prefix to prepend
    /// @param input Array of field elements to hash
    /// @return uint256 Resulting hash
    function poseidonHashWithPrefix(string memory prefix, uint256[] memory input) public view returns (uint256) {
        uint256[3] memory state = initialState();

        uint256[] memory prefixArray = new uint256[](1);
        prefixArray[0] = prefixToField(prefix);
        state = update(state, prefixArray);
        state = update(state, input);

        return state[0];
    }

    /// @notice Hashes message fields with public key and signature data
    /// @dev Implements message hashing as specified in the signing scheme
    /// @param fields Array of message fields
    /// @param publicKey Public key point
    /// @param r X-coordinate of signature point
    /// @param prefix Network-specific prefix
    /// @return uint256 Resulting message hash
    function hashMessage(
        uint256[] memory fields,
        Point memory publicKey,
        uint256 r,
        string memory prefix
    ) public view returns (uint256) {
        // Pre-allocate array and copy fields
        uint256[] memory fullInput = new uint256[](fields.length + 3);

        assembly {
            let length := mload(fields)
            let srcPtr := add(fields, 0x20)
            let destPtr := add(fullInput, 0x20)
            // Copy fields array
            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                mstore(add(destPtr, mul(i, 0x20)), mload(add(srcPtr, mul(i, 0x20))))
            }
            // Append public key and signature
            mstore(add(destPtr, mul(length, 0x20)), mload(publicKey))
            mstore(add(destPtr, mul(add(length, 1), 0x20)), mload(add(publicKey, 0x20)))
            mstore(add(destPtr, mul(add(length, 2), 0x20)), r)
        }

        // Use cached prefix value
        uint256[3] memory state = initialState();
        uint256[] memory prefixArray = new uint256[](1);
        prefixArray[0] = keccak256(bytes(prefix)) == keccak256(bytes("MinaSignatureMainnet"))
            ? MINA_PREFIX_FIELD
            : CODA_PREFIX_FIELD;

        state = update(state, prefixArray);
        state = update(state, fullInput);

        return state[0];
    }
}
