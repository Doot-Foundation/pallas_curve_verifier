// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PallasConstantsLegacy.sol";
import "./PallasCurveLegacy.sol";
import "hardhat/console.sol";

/**
 * @title PoseidonLegacy
 * @dev Implementation of Poseidon hash function for t = 3 (2 inputs)
 */

contract PoseidonLegacy is PallasCurveLegacy, PallasConstantsLegacy {
    uint256 internal constant BITS_PER_FIELD = 254;
    uint256 internal constant CODA_PREFIX_FIELD =
        240717916736854602989207148466022993262069182275;
    uint256 internal constant MINA_PREFIX_FIELD =
        664504924603203994814403132056773144791042910541;

    struct HashInputLegacy {
        uint256[] fields;
        bool[] bits;
    }

    /// @notice Computes x^5 mod FIELD_MODULUS
    /// @dev Optimized power5 implementation using square-and-multiply
    /// @param x Base value
    /// @return uint256 Result of x^5
    function power5(uint256 x) internal pure returns (uint256) {
        uint256 x2 = mulmod(x, x, FIELD_MODULUS);
        uint256 x4 = mulmod(x2, x2, FIELD_MODULUS);
        return mulmod(x4, x, FIELD_MODULUS);
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
        // Unroll the loops for gas efficiency
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

    /// @notice Performs the Poseidon permutation
    /// @dev Main cryptographic operation including rounds of substitution and diffusion
    /// @param state Input state array
    /// @return uint256[3] Permuted state
    function poseidonPermutation(
        uint256[3] memory state
    ) internal view returns (uint256[3] memory) {
        uint256 offset = 0;

        if (POSEIDON_HAS_INITIAL_ROUND_CONSTANT) {
            state[0] = addmod(state[0], roundConstants[0][0], FIELD_MODULUS);
            state[1] = addmod(state[1], roundConstants[0][1], FIELD_MODULUS);
            state[2] = addmod(state[2], roundConstants[0][2], FIELD_MODULUS);
            offset = 1;
        }

        for (uint256 round = 0; round < POSEIDON_FULL_ROUNDS; round++) {
            state[0] = power5(state[0]);
            state[1] = power5(state[1]);
            state[2] = power5(state[2]);

            state = mdsMultiply(state);

            state[0] = addmod(
                state[0],
                getRoundConstant(round + offset, 0),
                FIELD_MODULUS
            );
            state[1] = addmod(
                state[1],
                getRoundConstant(round + offset, 1),
                FIELD_MODULUS
            );
            state[2] = addmod(
                state[2],
                getRoundConstant(round + offset, 2),
                FIELD_MODULUS
            );
        }

        return state;
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

        uint256 n = ((input.length + POSEIDON_RATE - 1) / POSEIDON_RATE) *
            POSEIDON_RATE;
        uint256[] memory paddedInput = new uint256[](n);
        for (uint256 i = 0; i < input.length; i++) {
            paddedInput[i] = input[i];
        }

        for (
            uint256 blockIndex = 0;
            blockIndex < n;
            blockIndex += POSEIDON_RATE
        ) {
            state[0] = addmod(state[0], paddedInput[blockIndex], FIELD_MODULUS);
            if (blockIndex + 1 < n) {
                state[1] = addmod(
                    state[1],
                    paddedInput[blockIndex + 1],
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
            for (uint j = 0; j < 8; j++) {
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
        uint256 numBitFields = (input.bits.length + BITS_PER_FIELD - 1) /
            BITS_PER_FIELD;
        uint256[] memory result = new uint256[](
            input.fields.length + numBitFields
        );

        for (uint256 i = 0; i < input.fields.length; i++) {
            result[i] = input.fields[i];
        }

        uint256 bitsProcessed = 0;
        for (uint256 i = 0; i < numBitFields; i++) {
            uint256 bitsToTake = bitsProcessed + BITS_PER_FIELD >
                input.bits.length
                ? input.bits.length - bitsProcessed
                : BITS_PER_FIELD;

            bool[] memory fieldBits = new bool[](BITS_PER_FIELD);
            for (uint256 j = 0; j < bitsToTake; j++) {
                fieldBits[j] = input.bits[bitsProcessed + j];
            }

            bytes memory fieldBytes = bitsToBytes(fieldBits);
            result[input.fields.length + i] = bytesToFieldElement(fieldBytes);
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

        for (uint256 i = 0; i < input1.fields.length; i++) {
            combinedFields[i] = input1.fields[i];
        }
        for (uint256 i = 0; i < input2.fields.length; i++) {
            combinedFields[input1.fields.length + i] = input2.fields[i];
        }

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
        HashInputLegacy memory messageInput = HashInputLegacy({
            fields: new uint256[](0),
            bits: stringToBits(message)
        });

        uint256[] memory pkFields = new uint256[](3);
        pkFields[0] = publicKey.x;
        pkFields[1] = publicKey.y;
        pkFields[2] = r;

        HashInputLegacy memory pkInput = HashInputLegacy({
            fields: pkFields,
            bits: new bool[](0)
        });

        HashInputLegacy memory fullInput = appendHashInputs(
            messageInput,
            pkInput
        );
        uint256[] memory packedFields = packToFieldsLegacy(fullInput);

        // Use cached prefix values
        uint256 prefixField = keccak256(bytes(prefix)) ==
            keccak256(bytes("MinaSignatureMainnet"))
            ? MINA_PREFIX_FIELD
            : CODA_PREFIX_FIELD;

        uint256[] memory prefixArray = new uint256[](1);
        prefixArray[0] = prefixField;

        uint256[3] memory state = initialState();
        state = update(state, prefixArray);
        state = update(state, packedFields);

        return state[0];
    }
}
