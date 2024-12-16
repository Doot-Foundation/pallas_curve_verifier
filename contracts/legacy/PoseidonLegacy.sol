// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PallasConstantsLegacy.sol";
import "./PallasCurveLegacy.sol";
import "hardhat/console.sol";

/**
 * @title PoseidonLegacy
 * @dev Implementation of Poseidon hash function for t = 3 (2 inputs)
 */

// ✅ String to Bits Conversion
// stringToInput(string) -> HashInputLegacy.bits(bits)
// ✅ HashInputLegacy Structure
// type HashInputLegacy = {
//     fields: Field[];
//     bits: boolean[]
// }
// ✅ Input Assembly
// let input = HashInputLegacy.append(message, { fields: [x, y, r], bits: [] });
// ✅ Bits to Fields Packing
// packToFieldsLegacy({ fields, bits })

contract PoseidonLegacy is PallasCurveLegacy, PallasConstantsLegacy {
    function power5(uint256 x) internal pure returns (uint256) {
        // x^5 = x^4 * x = (x^2)^2 * x
        uint256 x2 = mulmod(x, x, FIELD_MODULUS); // x^2
        uint256 x4 = mulmod(x2, x2, FIELD_MODULUS); // x^4
        return mulmod(x4, x, FIELD_MODULUS); // x^5
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
            round < (POSEIDON_FULL_ROUNDS + 1) && pos < 3, // +1 for initial round constant
            "Invalid round constant indices"
        );
        return roundConstants[round][pos];
    }

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
            // Power 5 operation
            for (uint256 i = 0; i < POSEIDON_STATE_SIZE; i++) {
                currentState[i] = power5(currentState[i]);
            }

            // Store old state exactly like JS does
            uint256[3] memory oldState = currentState;

            // MDS multiply and add round constants, exactly like JS
            for (uint256 i = 0; i < POSEIDON_STATE_SIZE; i++) {
                // Do the dot product first
                currentState[i] = 0;
                for (uint256 j = 0; j < POSEIDON_STATE_SIZE; j++) {
                    currentState[i] = addmod(
                        currentState[i],
                        mulmod(getMdsValue(i, j), oldState[j], FIELD_MODULUS),
                        FIELD_MODULUS
                    );
                }

                // Then add round constant
                currentState[i] = addmod(
                    currentState[i],
                    getRoundConstant(round + offset, i),
                    FIELD_MODULUS
                );
            }
        }

        return currentState;
    }

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

    struct HashInputLegacy {
        uint256[] fields;
        bool[] bits;
    }

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
        uint256 length = packedFields.length;

        console.log("PACKED FIELDS SOLIDITY:");
        for (uint256 i = 0; i < length; i++) {
            console.log(" ", packedFields[i]);
        }

        return poseidonLegacyHashWithPrefix(prefix, packedFields);
    }

    function bitsToFieldBytes(
        bool[] memory bits,
        uint256 start,
        uint256 length
    ) internal pure returns (bytes memory) {
        // Calculate bytes needed (ceiling of length/8)
        uint256 numBytes = (length + 7) / 8;
        bytes memory result = new bytes(numBytes);

        // Process 8 bits at a time
        for (uint256 byteIdx = 0; byteIdx < numBytes; byteIdx++) {
            uint8 byteVal = 0;
            for (uint256 i = 0; i < 8; i++) {
                uint256 bitIdx = start + byteIdx * 8 + i;
                // Only process if within our length
                if (bitIdx < start + length && bitIdx < bits.length) {
                    // Matching JS: byte |= 1 << i
                    if (bits[bitIdx]) {
                        byteVal |= uint8(1 << i);
                    }
                }
            }
            result[byteIdx] = bytes1(byteVal);
        }
        return result;
    }

    function bytesToFieldExact(bytes memory b) internal pure returns (uint256) {
        // Exactly matching JS readBytes implementation:
        // let x = 0n;
        // let bitPosition = 0n;
        // for (let i = start; i < end; i++) {
        //     x += BigInt(bytes[i]) << bitPosition;
        //     bitPosition += 8n;
        // }
        uint256 x = 0;
        for (uint256 i = 0; i < b.length; i++) {
            x += uint256(uint8(b[i])) << (i * 8);
        }
        return x % FIELD_MODULUS;
    }

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

    function poseidonLegacyHash(
        uint256[] memory input
    ) public view returns (uint256) {
        uint256[3] memory state = initialState();
        state = update(state, input);

        return state[0];
    }

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

    function prefixToField(
        string memory prefix
    ) internal pure returns (uint256) {
        bytes memory prefixBytes = bytes(prefix);
        require(prefixBytes.length < 32, "prefix too long");

        uint256 result = 0;
        for (uint i = 0; i < 32; i++) {
            if (i < prefixBytes.length) {
                result |= uint256(uint8(prefixBytes[i])) << (i * 8);
            }
        }

        return result % FIELD_MODULUS;
    }

    /**
     * @dev Initial state array [0, 0, 0]
     */
    function initialState() internal pure returns (uint256[3] memory) {
        return [uint256(0), uint256(0), uint256(0)];
    }

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
}
