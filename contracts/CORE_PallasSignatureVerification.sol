// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PallasConstants.sol";
import "./PallasTypes.sol";
import "./PallasCurve.sol";
import "./PoseidonT3.sol";
import "hardhat/console.sol";

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
    uint256 public verificationCounter;
    mapping(uint256 => VerificationState) public signatureLifeCycle;

    struct VerificationState {
        uint256 atStep;
        CircuitString messageCircuitString;
        uint256[] messageFields;
        uint256[] hashInput;
        uint256 hashGenerated;
        Point hP;
        Point negHp;
        Point sG;
        Point finalR;
    }

    function clearArrays(uint256 verificationId) internal {
        delete signatureLifeCycle[verificationId].messageFields;
        delete signatureLifeCycle[verificationId].hashInput;
    }

    // Helper function to clean up storage after verification
    function cleanupVerification(uint256 verificationId) public {
        delete signatureLifeCycle[verificationId];
    }

    // Helper function to get current state
    function getVerificationState(
        uint256 verificationId
    ) public view returns (VerificationState memory state) {
        VerificationState storage returnedState = signatureLifeCycle[
            verificationId
        ];
        return returnedState;
    }

    /**
     * @dev Check if a point is a valid Pallas curve point
     */
    function isValidPublicKey(Point memory point) public pure returns (bool) {
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

    function step1_prepareMessage(
        string calldata message
    ) public returns (uint256[] memory) {
        verificationCounter++;
        uint256 currentId = verificationCounter;

        clearArrays(currentId);

        // Convert to field using the same process as o1js
        uint256 messageField = stringToField(message);

        // Store in state
        signatureLifeCycle[currentId].messageFields = new uint256[](1);
        signatureLifeCycle[currentId].messageFields[0] = messageField;

        signatureLifeCycle[currentId].atStep = 1;

        return signatureLifeCycle[currentId].messageFields;
    }

    function step2_prepareHashInput(
        uint256 verificationId,
        Point calldata publicKey,
        uint256 r
    ) public returns (uint256[] memory) {
        require(
            signatureLifeCycle[verificationId].messageFields.length > 0,
            "No message fields found"
        );

        uint256[] memory hashInput = new uint256[](4); // Length 4 for [messageField, pub.x, pub.y, r]
        hashInput[0] = signatureLifeCycle[verificationId].messageFields[0]; // The already hashed message
        hashInput[1] = publicKey.x;
        hashInput[2] = publicKey.y;
        hashInput[3] = r;

        signatureLifeCycle[verificationId].hashInput = hashInput;
        signatureLifeCycle[verificationId].atStep = 2;

        return hashInput;
    }

    function step3_computeHash(
        uint256 verificationId
    ) public returns (uint256) {
        require(
            signatureLifeCycle[verificationId].atStep == 2,
            "Must complete step 2 first"
        );
        require(
            signatureLifeCycle[verificationId].hashInput.length > 0,
            "No hash input found"
        );

        uint256[] memory hashInput = signatureLifeCycle[verificationId]
            .hashInput;
        uint256 hashGenerated = hashPoseidonWithPrefix(
            SIGNATURE_PREFIX,
            hashInput
        );

        signatureLifeCycle[verificationId].hashGenerated = hashGenerated;
        signatureLifeCycle[verificationId].atStep = 3;

        // Clear arrays we don't need anymore
        delete signatureLifeCycle[verificationId].messageFields;
        delete signatureLifeCycle[verificationId].hashInput;

        console.log("Hash computed:", hashGenerated);
        return hashGenerated;
    }

    function step4_computeHP(
        uint256 verificationId,
        Point calldata publicKey
    ) public returns (Point memory) {
        require(
            signatureLifeCycle[verificationId].atStep == 3,
            "Must complete step 3 first"
        );

        uint256 hashGenerated = signatureLifeCycle[verificationId]
            .hashGenerated;
        Point memory result = scalarMul(publicKey, hashGenerated);

        signatureLifeCycle[verificationId].hP = result;
        signatureLifeCycle[verificationId].atStep = 4;

        console.log("hP computed - x:", result.x, "y:", result.y);
        return result;
    }

    function step5_negatePoint(
        uint256 verificationId
    ) public returns (Point memory) {
        require(
            signatureLifeCycle[verificationId].atStep == 4,
            "Must complete step 4 first"
        );

        Point memory hP = signatureLifeCycle[verificationId].hP;
        Point memory negHp = Point(hP.x, FIELD_MODULUS - hP.y);

        signatureLifeCycle[verificationId].negHp = negHp;
        signatureLifeCycle[verificationId].atStep = 5;

        return negHp;
    }

    function step6_computeSG(
        uint256 verificationId,
        uint256 s
    ) public returns (Point memory) {
        require(
            signatureLifeCycle[verificationId].atStep == 5,
            "Must complete step 5 first"
        );

        Point memory G = Point(G_X, G_Y);
        Point memory sG = scalarMul(G, s);

        signatureLifeCycle[verificationId].sG = sG;
        signatureLifeCycle[verificationId].atStep = 6;

        console.log("sG computed - x:", sG.x, "y:", sG.y);
        return sG;
    }

    function step7_finalAddition(
        uint256 verificationId
    ) public returns (Point memory) {
        require(
            signatureLifeCycle[verificationId].atStep == 6,
            "Must complete step 6 first"
        );

        Point memory sG = signatureLifeCycle[verificationId].sG;
        Point memory negHp = signatureLifeCycle[verificationId].negHp;

        Point memory result = addPoints(sG, negHp);

        signatureLifeCycle[verificationId].finalR = result;
        signatureLifeCycle[verificationId].atStep = 7;

        console.log("Final addition - x:", result.x, "y:", result.y);
        return result;
    }

    function step8_verify(
        uint256 verificationId,
        uint256 expectedR
    ) public view returns (bool) {
        require(
            signatureLifeCycle[verificationId].atStep == 7,
            "Must complete step 7 first"
        );

        Point memory r = signatureLifeCycle[verificationId].finalR;

        console.log("Verifying...");
        console.log("Computed x:", r.x);
        console.log("Expected x:", expectedR);
        console.log("y value:", r.y);
        console.log("y mod 2:", r.y % 2);

        bool xMatches = r.x == expectedR;
        bool yIsEven = r.y % 2 == 0;

        console.log("x matches:", xMatches);
        console.log("y is even:", yIsEven);

        return xMatches && yIsEven;
    }

    function stringToCharacterArray(
        string memory str
    ) internal pure returns (uint256[] memory) {
        bytes memory strBytes = bytes(str);
        uint256[] memory chars = new uint256[](strBytes.length);

        for (uint i = 0; i < strBytes.length; i++) {
            // Convert each character to its character code (equivalent to charCodeAt)
            chars[i] = uint256(uint8(strBytes[i]));
        }

        // Pad with null characters (value 0) up to maxLength if needed
        uint256[] memory paddedChars;
        if (chars.length < DEFAULT_STRING_LENGTH) {
            paddedChars = new uint256[](DEFAULT_STRING_LENGTH);
            for (uint i = 0; i < chars.length; i++) {
                paddedChars[i] = chars[i];
            }
            // Rest are initialized to 0 (null character)
        } else {
            paddedChars = chars;
        }

        return paddedChars;
    }

    struct Character {
        uint256 value;
    }

    struct CircuitString {
        Character[DEFAULT_STRING_LENGTH] values;
    }

    Character[DEFAULT_STRING_LENGTH] public latestGenerated;
    uint256 public latestHash;

    function getAllLatestGenerated()
        public
        view
        returns (Character[DEFAULT_STRING_LENGTH] memory)
    {
        return latestGenerated;
    }

    // Main public interface - equivalent to CircuitString.fromString() in JS
    function fromString(string memory str) public {
        bytes memory strBytes = bytes(str);
        require(
            strBytes.length <= DEFAULT_STRING_LENGTH,
            "CircuitString.fromString: input string exceeds max length!"
        );

        // Create and fill the character array
        Character[] memory chars = new Character[](DEFAULT_STRING_LENGTH);

        // Fill with actual characters
        for (uint i = 0; i < strBytes.length; i++) {
            chars[i] = Character(uint256(uint8(strBytes[i])));
            latestGenerated[i] = Character(uint256(uint8(strBytes[i])));
        }

        // Fill remaining slots with null characters
        for (uint i = strBytes.length; i < DEFAULT_STRING_LENGTH; i++) {
            chars[i] = Character(0);
            latestGenerated[i] = Character(0);
        }
        // return CircuitStringStruct(chars);
    }

    function stringToField(string memory str) internal view returns (uint256) {
        bytes memory strBytes = bytes(str);

        // Create array of character codes
        uint256[] memory chars = new uint256[](DEFAULT_STRING_LENGTH);

        // Fill with actual characters
        for (uint i = 0; i < strBytes.length; i++) {
            chars[i] = uint256(uint8(strBytes[i]));
        }

        // Rest are already 0 (null characters)

        console.log("Character array size:", chars.length);
        for (uint i = 0; i < strBytes.length; i++) {
            console.log("Char at %d: %d", i, chars[i]);
        }

        // Hash all 128 characters as one array
        uint256[3] memory state = [uint256(0), uint256(0), uint256(0)];
        state = update(state, chars);

        return state[0];
    }

    function hash(Character[DEFAULT_STRING_LENGTH] memory input) public {
        uint256[] memory values = new uint256[](DEFAULT_STRING_LENGTH);
        for (uint i = 0; i < input.length; i++) {
            values[i] = input[i].value;
        }

        latestHash = hashPoseidon(values);
    }
}
