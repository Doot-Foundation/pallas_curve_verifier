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
    mapping(uint256 => VerificationState) public signatureVerify;

    struct VerificationState {
        uint256 atStep;
        uint256[] messageFields;
        uint256[] hashInput;
        uint256 hash;
        Point hP;
        Point negHp;
        Point sG;
        Point finalR;
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

    function clearArrays(uint256 verificationId) internal {
        delete signatureVerify[verificationId].messageFields;
        delete signatureVerify[verificationId].hashInput;
    }

    function step1_prepareMessage(
        string calldata message
    ) public returns (uint256[] memory) {
        verificationCounter++;
        uint256 currentId = verificationCounter;

        // Clear any existing arrays
        clearArrays(currentId);

        bytes memory messageBytes = bytes(message);
        uint256[] memory fields = new uint256[](
            (messageBytes.length + 31) / 32
        );

        for (uint i = 0; i < fields.length; i++) {
            uint256 field = 0;
            for (
                uint j = 0;
                j < 32 && (i * 32 + j) < messageBytes.length;
                j++
            ) {
                field |= uint256(uint8(messageBytes[i * 32 + j])) << (j * 8);
            }
            fields[i] = field % FIELD_MODULUS;
        }

        // Create new dynamic array in storage
        signatureVerify[currentId].messageFields = new uint256[](fields.length);
        for (uint i = 0; i < fields.length; i++) {
            signatureVerify[currentId].messageFields[i] = fields[i];
        }

        signatureVerify[currentId].atStep = 1;

        console.log("Message converted to fields:", fields[0]);
        console.log("Verification ID:", currentId);
        return fields;
    }

    function step2_prepareHashInput(
        uint256 verificationId,
        Point calldata publicKey,
        uint256 r
    ) public returns (uint256[] memory) {
        require(
            signatureVerify[verificationId].atStep == 1,
            "Must complete step 1 first"
        );

        uint256[] memory messageFields = signatureVerify[verificationId]
            .messageFields;
        require(messageFields.length > 0, "No message fields found");

        uint256[] memory hashInput = new uint256[](messageFields.length + 3);

        for (uint i = 0; i < messageFields.length; i++) {
            hashInput[i] = messageFields[i];
        }

        hashInput[messageFields.length] = publicKey.x;
        hashInput[messageFields.length + 1] = publicKey.y;
        hashInput[messageFields.length + 2] = r;

        // Store in state with proper array handling
        signatureVerify[verificationId].hashInput = new uint256[](
            hashInput.length
        );
        for (uint i = 0; i < hashInput.length; i++) {
            signatureVerify[verificationId].hashInput[i] = hashInput[i];
        }

        signatureVerify[verificationId].atStep = 2;

        console.log("Hash input prepared. Length:", hashInput.length);
        return hashInput;
    }

    function step3_computeHash(
        uint256 verificationId
    ) public returns (uint256) {
        require(
            signatureVerify[verificationId].atStep == 2,
            "Must complete step 2 first"
        );
        require(
            signatureVerify[verificationId].hashInput.length > 0,
            "No hash input found"
        );

        uint256[] memory hashInput = signatureVerify[verificationId].hashInput;
        uint256 hash = hashWithPrefix(SIGNATURE_PREFIX, hashInput);

        signatureVerify[verificationId].hash = hash;
        signatureVerify[verificationId].atStep = 3;

        // Clear arrays we don't need anymore
        delete signatureVerify[verificationId].messageFields;
        delete signatureVerify[verificationId].hashInput;

        console.log("Hash computed:", hash);
        return hash;
    }

    function step4_computeHP(
        uint256 verificationId,
        Point calldata publicKey
    ) public returns (Point memory) {
        require(
            signatureVerify[verificationId].atStep == 3,
            "Must complete step 3 first"
        );

        uint256 hash = signatureVerify[verificationId].hash;
        Point memory result = scalarMul(publicKey, hash);

        signatureVerify[verificationId].hP = result;
        signatureVerify[verificationId].atStep = 4;

        console.log("hP computed - x:", result.x, "y:", result.y);
        return result;
    }

    function step5_negatePoint(
        uint256 verificationId
    ) public returns (Point memory) {
        require(
            signatureVerify[verificationId].atStep == 4,
            "Must complete step 4 first"
        );

        Point memory hP = signatureVerify[verificationId].hP;
        Point memory negHp = Point(hP.x, FIELD_MODULUS - hP.y);

        signatureVerify[verificationId].negHp = negHp;
        signatureVerify[verificationId].atStep = 5;

        return negHp;
    }

    function step6_computeSG(
        uint256 verificationId,
        uint256 s
    ) public returns (Point memory) {
        require(
            signatureVerify[verificationId].atStep == 5,
            "Must complete step 5 first"
        );

        Point memory G = Point(G_X, G_Y);
        Point memory sG = scalarMul(G, s);

        signatureVerify[verificationId].sG = sG;
        signatureVerify[verificationId].atStep = 6;

        console.log("sG computed - x:", sG.x, "y:", sG.y);
        return sG;
    }

    function step7_finalAddition(
        uint256 verificationId
    ) public returns (Point memory) {
        require(
            signatureVerify[verificationId].atStep == 6,
            "Must complete step 6 first"
        );

        Point memory sG = signatureVerify[verificationId].sG;
        Point memory negHp = signatureVerify[verificationId].negHp;

        Point memory result = addPoints(sG, negHp);

        signatureVerify[verificationId].finalR = result;
        signatureVerify[verificationId].atStep = 7;

        console.log("Final addition - x:", result.x, "y:", result.y);
        return result;
    }

    function step8_verify(
        uint256 verificationId,
        uint256 expectedR
    ) public view returns (bool) {
        require(
            signatureVerify[verificationId].atStep == 7,
            "Must complete step 7 first"
        );

        Point memory r = signatureVerify[verificationId].finalR;

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

    // Helper function to clean up storage after verification
    function cleanupVerification(uint256 verificationId) public {
        delete signatureVerify[verificationId];
    }

    // Helper function to get current state
    function getVerificationState(
        uint256 verificationId
    )
        public
        view
        returns (
            uint256 atStep,
            uint256[] memory messageFields,
            uint256[] memory hashInput,
            uint256 hash,
            Point memory hP,
            Point memory negHp,
            Point memory sG,
            Point memory finalR
        )
    {
        VerificationState storage state = signatureVerify[verificationId];
        return (
            state.atStep,
            state.messageFields,
            state.hashInput,
            state.hash,
            state.hP,
            state.negHp,
            state.sG,
            state.finalR
        );
    }
}
