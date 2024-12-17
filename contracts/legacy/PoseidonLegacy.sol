// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PallasConstantsLegacy.sol";
import "./PallasCurveLegacy.sol";
import "hardhat/console.sol";

/**
 * @title PoseidonLegacy
 * @dev Implementation of Poseidon hash function for t = 3 (2 inputs)
 */

contract PoseidonLegacy is PallasCurveLegacy, PallasConstantsLegacy {
    struct HashInputLegacy {
        uint256[] fields;
        bool[] bits;
    }

    /// @notice Computes x^5 mod FIELD_MODULUS
    /// @dev Optimized power5 implementation using square-and-multiply
    /// @param x Base value
    /// @return uint256 Result of x^5
    function power5(uint256 x) internal pure returns (uint256) {
        uint256 x2 = mulmod(x, x, FIELD_MODULUS); // x^2
        uint256 x4 = mulmod(x2, x2, FIELD_MODULUS); // x^4
        return mulmod(x4, x, FIELD_MODULUS); // x^5
    }

    /// @notice Initial state array [0, 0, 0]
    /// @dev Creates starting state for Poseidon hash
    /// @return uint256[3] Initial state array
    function initialState() internal pure returns (uint256[3] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }

    /// @notice Retrieves value from MDS matrix at specified position
    /// @dev Used in the Poseidon permutation
    /// @param row Row index
    /// @param col Column index
    /// @return uint256 Matrix value at position
    function getMdsValue(
        uint256 row,
        uint256 col
    ) internal view returns (uint256) {
        require(row < 3 && col < 3, "Invalid MDS indices");
        return mdsMatrix[row][col];
    }

    /// @notice Gets round constant for specified round and position
    /// @dev Access round constants array with bounds checking
    /// @param round Round number
    /// @param pos Position in the round
    /// @return uint256 Round constant value
    function getRoundConstant(
        uint256 round,
        uint256 pos
    ) internal view returns (uint256) {
        require(
            round < (POSEIDON_FULL_ROUNDS + 1) && pos < 3, // +1 for initial round constant
            "Invalid round constant indices"
        );
        return roundConstants[round][pos];
    }

    /// @notice Performs matrix multiplication with MDS matrix
    /// @dev Core operation in Poseidon permutation
    /// @param state Current state array
    /// @return result Result of matrix multiplication
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

    /// @notice Performs the Poseidon permutation
    /// @dev Main cryptographic operation including rounds of substitution and diffusion
    /// @param state Input state array
    /// @return uint256[3] Permuted state
    function poseidonPermutation(
        uint256[3] memory state
    ) internal view returns (uint256[3] memory) {
        uint256[3] memory currentState = state;
        uint256 offset = 0;

        // Initial round constant if needed
        if (POSEIDON_HAS_INITIAL_ROUND_CONSTANT) {
            for (uint256 i = 0; i < POSEIDON_STATE_SIZE; i++) {
                currentState[i] = addmod(
                    currentState[i],
                    roundConstants[0][i],
                    FIELD_MODULUS
                );
            }
            offset = 1;
        }

        // Main rounds
        for (uint256 round = 0; round < POSEIDON_FULL_ROUNDS; round++) {
            // Power 5 operation using optimized power5
            for (uint256 i = 0; i < POSEIDON_STATE_SIZE; i++) {
                currentState[i] = power5(currentState[i]);
            }

            currentState = mdsMultiply(currentState);

            for (uint256 i = 0; i < POSEIDON_STATE_SIZE; i++) {
                currentState[i] = addmod(
                    currentState[i],
                    getRoundConstant(round + offset, i),
                    FIELD_MODULUS
                );
            }
        }

        return currentState;
    }

    /// @notice Updates hash state with input
    /// @dev Processes input in rate-sized blocks
    /// @param state Current state
    /// @param input Input values
    /// @return uint256[3] Updated state
    function update(
        uint256[3] memory state,
        uint256[] memory input
    ) internal view returns (uint256[3] memory) {
        if (input.length == 0) {
            return poseidonPermutation(state);
        }

        // Pad input with zeros to multiple of rate (matching JS)
        uint256 n = ((input.length + POSEIDON_RATE - 1) / POSEIDON_RATE) *
            POSEIDON_RATE;
        uint256[] memory paddedInput = new uint256[](n);
        for (uint256 i = 0; i < input.length; i++) {
            paddedInput[i] = input[i];
        }
        // Rest are initialized to 0 by default

        for (
            uint256 blockIndex = 0;
            blockIndex < n;
            blockIndex += POSEIDON_RATE
        ) {
            for (uint256 i = 0; i < POSEIDON_RATE; i++) {
                state[i] = addmod(
                    state[i],
                    paddedInput[blockIndex + i],
                    FIELD_MODULUS
                );
            }
            state = poseidonPermutation(state);
        }
        return state;
    }

    /// @notice Converts string to array of bits
    /// @dev Matches o1js bit ordering
    /// @param str Input string
    /// @return bool[] Array of bits
    function stringToBits(
        string memory str
    ) internal pure returns (bool[] memory) {
        bytes memory strBytes = bytes(str);
        bool[] memory bits = new bool[](strBytes.length * 8);

        for (uint i = 0; i < strBytes.length; i++) {
            uint8 b = uint8(strBytes[i]);

            // Convert to bits in JS order
            for (uint j = 0; j < 8; j++) {
                // JavaScript does: false, true, false, true... for byte 84
                bits[i * 8 + j] = (b & (1 << (7 - j))) != 0;
            }
        }
        return bits;
    }

    /// @notice Converts bits to bytes
    /// @dev Used in field element conversion
    /// @param bits Array of bits
    /// @return bytes Resulting byte array
    function bitsToBytes(
        bool[] memory bits
    ) internal pure returns (bytes memory) {
        uint256 numBytes = (bits.length + 7) / 8;
        bytes memory result = new bytes(numBytes);

        for (uint256 i = 0; i < numBytes; i++) {
            uint8 byteVal = 0;
            for (uint8 bit = 0; bit < 8; bit++) {
                uint256 bitIndex = i * 8 + bit;
                if (bitIndex < bits.length && bits[bitIndex]) {
                    // Match JS: x += BigInt(bytes[i]) << bitPosition
                    byteVal |= uint8(1 << bit);
                }
            }
            result[i] = bytes1(byteVal);
        }
        return result;
    }

    /// @notice Converts bytes to field element
    /// @dev Reduces result modulo FIELD_MODULUS
    /// @param b Input bytes
    /// @return uint256 Field element
    function bytesToFieldElement(
        bytes memory b
    ) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            // Match JS: x += BigInt(bytes[i]) << bitPosition
            result += uint256(uint8(b[i])) << (i * 8);
        }
        return result % FIELD_MODULUS;
    }

    /// @notice Converts prefix string to field element
    /// @dev Uses little-endian byte ordering
    /// @param prefix Input string
    /// @return uint256 Field element
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

    /// @notice Packs HashInputLegacy into array of field elements
    /// @dev Handles both field and bit inputs
    /// @param input HashInputLegacy struct
    /// @return uint256[] Array of packed field elements
    function packToFieldsLegacy(
        HashInputLegacy memory input
    ) internal pure returns (uint256[] memory) {
        uint256 BITS_PER_FIELD = 254; // sizeInBits - 1 as per JS
        uint256 numBitFields = (input.bits.length + BITS_PER_FIELD - 1) /
            BITS_PER_FIELD;

        uint256[] memory result = new uint256[](
            input.fields.length + numBitFields
        );

        // Copy original fields first
        for (uint256 i = 0; i < input.fields.length; i++) {
            result[i] = input.fields[i];
        }

        uint256 bitsProcessed = 0;
        for (uint256 i = 0; i < numBitFields; i++) {
            uint256 bitsToTake = bitsProcessed + BITS_PER_FIELD >
                input.bits.length
                ? input.bits.length - bitsProcessed
                : BITS_PER_FIELD;

            // Create padded array of size BITS_PER_FIELD (exactly like JS)
            bool[] memory fieldBits = new bool[](BITS_PER_FIELD);
            // Copy available bits
            for (uint256 j = 0; j < bitsToTake; j++) {
                fieldBits[j] = input.bits[bitsProcessed + j];
            }
            // Rest remains false (matching JS padding)

            // Convert to bytes first (matching JS flow)
            bytes memory fieldBytes = bitsToBytes(fieldBits);

            // Convert bytes to field element
            uint256 fieldElement = bytesToFieldElement(fieldBytes);

            result[input.fields.length + i] = fieldElement;
            bitsProcessed += bitsToTake;
        }

        return result;
    }

    /// @notice Combines two HashInputLegacy structs
    /// @dev Concatenates both fields and bits arrays
    /// @param input1 First input
    /// @param input2 Second input
    /// @return HashInputLegacy Combined input
    function appendHashInputs(
        HashInputLegacy memory input1,
        HashInputLegacy memory input2
    ) internal pure returns (HashInputLegacy memory) {
        uint256[] memory combinedFields = new uint256[](
            input1.fields.length + input2.fields.length
        );
        bool[] memory combinedBits = new bool[](
            input1.bits.length + input2.bits.length
        );

        // Combine fields
        for (uint256 i = 0; i < input1.fields.length; i++) {
            combinedFields[i] = input1.fields[i];
        }
        for (uint256 i = 0; i < input2.fields.length; i++) {
            combinedFields[input1.fields.length + i] = input2.fields[i];
        }

        // Combine bits
        for (uint256 i = 0; i < input1.bits.length; i++) {
            combinedBits[i] = input1.bits[i];
        }
        for (uint256 i = 0; i < input2.bits.length; i++) {
            combinedBits[input1.bits.length + i] = input2.bits[i];
        }

        return HashInputLegacy({fields: combinedFields, bits: combinedBits});
    }

    // @notice Computes Poseidon hash of input array
    /// @dev Main hashing function without prefix
    /// @param input Array to hash
    /// @return uint256 Hash result
    function poseidonLegacyHash(
        uint256[] memory input
    ) public view returns (uint256) {
        uint256[3] memory state = initialState();
        state = update(state, input);

        return state[0];
    }

    /// @notice Computes Poseidon hash with prefix
    /// @dev Hashes prefix followed by input array
    /// @param prefix String prefix
    /// @param input Array to hash
    /// @return uint256 Hash result
    function poseidonLegacyHashWithPrefix(
        string memory prefix,
        uint256[] memory input
    ) public view returns (uint256) {
        // Start with initial state [0, 0, 0]
        uint256[3] memory state = initialState();

        // Create prefix array with single element
        uint256[] memory prefixArray = new uint256[](1);
        prefixArray[0] = prefixToField(prefix);

        // First update with prefix
        state = update(state, prefixArray);

        // Then update with input
        state = update(state, input);

        return state[0];
    }

    /// @notice Hashes message with public key and signature data
    /// @dev Complete message hashing matching o1js implementation
    /// @param message String message
    /// @param publicKey Public key point
    /// @param r Signature r value
    /// @param prefix Network prefix
    /// @return uint256 Hash result
    function hashMessageLegacy(
        string memory message,
        Point memory publicKey,
        uint256 r,
        string memory prefix
    ) internal view returns (uint256) {
        // Create message input (only bits, no fields)
        HashInputLegacy memory messageInput = HashInputLegacy({
            fields: new uint256[](0),
            bits: stringToBits(message)
        });

        // Create public key and r input (only fields, no bits)
        uint256[] memory pkFields = new uint256[](3);
        pkFields[0] = publicKey.x;
        pkFields[1] = publicKey.y;
        pkFields[2] = r;
        HashInputLegacy memory pkInput = HashInputLegacy({
            fields: pkFields,
            bits: new bool[](0)
        });

        // Append the inputs
        HashInputLegacy memory fullInput = appendHashInputs(
            messageInput,
            pkInput
        );

        // Pack fields exactly like JS
        uint256[] memory packedFields = packToFieldsLegacy(fullInput);

        return poseidonLegacyHashWithPrefix(prefix, packedFields);
    }
}
