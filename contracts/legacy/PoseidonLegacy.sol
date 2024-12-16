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

    function hashMessageLegacy(
        string memory message,
        Point memory publicKey,
        uint256 r,
        string memory prefix
    ) internal view returns (uint256) {
        console.log("Starting hashMessageLegacy with:");
        console.log("Message:", message);
        console.log("Public Key X:", publicKey.x);
        console.log("Public Key Y:", publicKey.y);
        console.log("r:", r);
        console.log("prefix:", prefix);

        // Convert string to bits
        bool[] memory messageBits = stringToBits(message);

        // Pack bits to fields
        uint256[] memory messageFields = packBitsToFields(messageBits);
        uint256[] memory fullInput = new uint256[](messageFields.length + 3);
        fullInput[0] = publicKey.x;
        fullInput[1] = publicKey.y;
        fullInput[2] = r;
        for (uint256 i = 0; i < messageFields.length; i++) {
            fullInput[i + 3] = messageFields[i];
        }

        for (uint i = 0; i < fullInput.length; i++) {
            console.log("Input field", i, ":", fullInput[i]);
        }

        // Hash with prefix
        return poseidonLegacyHashWithPrefix(prefix, fullInput);
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
            // Convert each byte to bits and reverse them
            bool[8] memory byteBits;
            for (uint j = 0; j < 8; j++) {
                byteBits[j] = (b & (1 << j)) != 0;
            }
            // Copy reversed bits
            for (uint j = 0; j < 8; j++) {
                bits[i * 8 + j] = byteBits[7 - j]; // Reverse the order
            }
        }

        return bits;
    }

    function packBitsToFields(
        bool[] memory bits
    ) internal pure returns (uint256[] memory) {
        uint256 chunkSize = 254;
        uint256 numFields = (bits.length + chunkSize - 1) / chunkSize;
        uint256[] memory fields = new uint256[](numFields);

        uint256 offset = 0;
        for (uint256 fieldIdx = 0; fieldIdx < numFields; fieldIdx++) {
            uint256 currentField = 0;
            uint256 remainingBits = bits.length - offset;
            uint256 bitsToProcess = remainingBits < chunkSize
                ? remainingBits
                : chunkSize;

            for (uint256 i = 0; i < bitsToProcess; i++) {
                if (bits[offset + i]) {
                    currentField |= (uint256(1) << i);
                }
            }

            fields[fieldIdx] = currentField;

            offset += chunkSize;
        }

        return fields;
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
}
