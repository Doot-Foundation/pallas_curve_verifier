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

    // /**
    //  * @dev Verifies a signature against a message and public key. Field[]
    //  */
    // function verifyFields(
    //     Signature memory signature,
    //     Point memory publicKey,
    //     uint256[] memory message
    // ) public pure returns (bool) {
    //     require(signature.s < SCALAR_MODULUS, "Invalid s value");
    //     require(signature.r < FIELD_MODULUS, "Invalid r value");
    //     require(isOnCurve(publicKey), "Public key not on curve");

    //     // Prepare hash input
    //     uint256[] memory hashInput = new uint256[](message.length + 3);
    //     for (uint i = 0; i < message.length; i++) {
    //         hashInput[i] = message[i];
    //     }
    //     hashInput[message.length] = publicKey.x;
    //     hashInput[message.length + 1] = publicKey.y;
    //     hashInput[message.length + 2] = signature.r;

    //     // Compute hash with testnet prefix
    //     uint256 h = hashWithPrefix(SIGNATURE_PREFIX, hashInput);

    //     // Compute R = s⋅G - h⋅P
    //     Point memory hP = scalarMul(publicKey, h);
    //     Point memory negHp = Point(hP.x, FIELD_MODULUS - hP.y); // Negate y coordinate

    //     Point memory sG = scalarMul(Point(G_X, G_Y), signature.s);
    //     Point memory r = addPoints(sG, negHp);

    //     // Verify r.x equals signature.r and r.y is even
    //     return r.x == signature.r && r.y % 2 == 0;
    // }

    /**
    //  * @dev Convenience function to verify a signature for a single field element message.
    //  * A Schnorr over the Pasta Curves.
    //  */
    // function verifyField(
    //     Signature memory signature,
    //     Point memory publicKey,
    //     uint256 message
    // ) public returns (bool) {
    //     uint256[] memory messageArray = new uint256[](1);
    //     messageArray[0] = message;
    //     return verifySignature(signature, publicKey, messageArray);
    // }

    // function verifyMessage(
    //     Signature calldata signature,
    //     Point calldata publicKey,
    //     string calldata message
    // ) public returns (bool) {
    //     console.log("Starting verification...");
    //     require(signature.s < SCALAR_MODULUS, "Invalid s value");
    //     require(signature.r < FIELD_MODULUS, "Invalid r value");

    //     console.log("Converting message to fields...");
    //     uint256[] memory messageFields = stringToFields(message);
    //     console.log("Message fields length:", messageFields.length);

    //     // Log first verification step
    //     console.log("Starting signature verification...");
    //     return verifySignature(signature, publicKey, messageFields);
    // }

    // function verifySignature(
    //     Signature memory signature,
    //     Point memory publicKey,
    //     uint256[] memory message
    // ) public returns (bool) {
    //     console.log("Preparing hash input...");
    //     // Hash preparation
    //     uint256[] memory hashInput = new uint256[](message.length + 3);
    //     for (uint i = 0; i < message.length; i++) {
    //         hashInput[i] = message[i];
    //     }
    //     hashInput[message.length] = publicKey.x;
    //     hashInput[message.length + 1] = publicKey.y;
    //     hashInput[message.length + 2] = signature.r;

    //     console.log("Computing hash...");
    //     uint256 h = hashWithPrefix(SIGNATURE_PREFIX, hashInput);
    //     console.log("Hash computed:", h);

    //     console.log("Computing scalar multiplication hP...");
    //     Point memory hP = scalarMul(publicKey, h);
    //     console.log("hP computed. x:", hP.x, "y:", hP.y);

    //     Point memory negHp = Point(hP.x, FIELD_MODULUS - hP.y);
    //     console.log("Computing scalar multiplication sG...");
    //     Point memory sG = scalarMul(Point(G_X, G_Y), signature.s);
    //     console.log("sG computed. x:", sG.x, "y:", sG.y);

    //     console.log("Computing final addition...");
    //     Point memory r = addPoints(sG, negHp);
    //     console.log("Final point computed. x:", r.x, "y:", r.y);

    //     return r.x == signature.r && r.y % 2 == 0;
    // }

    struct VerificationState {
        uint256[] messageFields;
        uint256[] hashInput;
        uint256 hash;
        Point hP;
        Point negHp;
        Point sG;
        Point finalR;
    }

    function step1_prepareMessage(
        string calldata message
    ) public pure returns (uint256[] memory) {
        return stringToFields(message);
    }

    function step2_prepareHashInput(
        uint256[] calldata messageFields,
        Point calldata publicKey,
        uint256 r
    ) public pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](messageFields.length + 3);
        for (uint i = 0; i < messageFields.length; i++) {
            result[i] = messageFields[i];
        }
        result[messageFields.length] = publicKey.x;
        result[messageFields.length + 1] = publicKey.y;
        result[messageFields.length + 2] = r;
        return result;
    }

    function step3_computeHash(
        uint256[] calldata hashInput
    ) public pure returns (uint256) {
        return hashWithPrefix(SIGNATURE_PREFIX, hashInput);
    }

    function step4_computeHP(
        Point calldata publicKey,
        uint256 hash
    ) public pure returns (Point memory) {
        return scalarMul(publicKey, hash);
    }

    function step5_negatePoint(
        Point calldata p
    ) public pure returns (Point memory) {
        return Point(p.x, FIELD_MODULUS - p.y);
    }

    function step6_computeSG(uint256 s) public pure returns (Point memory) {
        return scalarMul(Point(G_X, G_Y), s);
    }

    function step7_finalAddition(
        Point calldata sG,
        Point calldata negHp
    ) public pure returns (Point memory) {
        return addPoints(sG, negHp);
    }

    function step8_verify(
        Point calldata r,
        uint256 expectedR
    ) public pure returns (bool) {
        console.log("Contract verification:");
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
}
