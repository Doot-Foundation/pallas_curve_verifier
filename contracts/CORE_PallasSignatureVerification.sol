// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PallasConstants.sol";
import "./PallasTypes.sol";
import "./PallasCurve.sol";
import "./PoseidonT3.sol";
import "hardhat/console.sol";

error InvalidPublicKey();
error StepSkipped();

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
    struct VerifyMessageState {
        uint8 atStep;
        Point publicKey;
        Signature signature;
        string message;
        uint256 messageHash;
        uint256 hashGenerated;
        Point hP;
        Point negHp;
        Point sG;
        Point finalR;
        uint256[4] hashInput;
    }
    struct VerifyFieldsState {
        bool init;
        bool mainnet;
        uint8 atStep;
        Point publicKey;
        Signature signature;
        uint256[] fields;
    }

    uint256 public vmCounter = 0;
    mapping(uint256 => address) public vmLifeCycleCreator;
    mapping(uint256 => VerifyMessageState) public vmLifeCycle;

    uint256 public vfCounter = 0;
    mapping(uint256 => address) public vfLifeCycleCreator;
    mapping(uint256 => VerifyFieldsState) public vfLifeCycle;

    modifier isVMCreator(uint256 id) {
        require(msg.sender == vmLifeCycleCreator[id]);
        _;
    }
    modifier isVFCreator(uint256 id) {
        require(msg.sender == vfLifeCycleCreator[id]);
        _;
    }
    modifier isValidVFId(uint256 id) {
        require(id < vfCounter);
        _;
    }
    modifier isValidVMId(uint256 id) {
        require(id < vmCounter);
        _;
    }

    function cleanupVMLifecycle(uint256 vmId) external isVMCreator(vmId) {
        delete vmLifeCycle[vmId];
    }

    function cleanupVFLifecycle(uint256 vfId) external isVFCreator(vfId) {
        delete vmLifeCycle[vfId];
    }

    function getVMState(
        uint256 vmId
    ) external view returns (VerifyMessageState memory state) {
        VerifyMessageState storage returnedState = vmLifeCycle[vmId];
        return returnedState;
    }

    function getVFState(
        uint256 vfId
    ) external view returns (VerifyFieldsState memory state) {
        VerifyFieldsState storage returnedState = vfLifeCycle[vfId];
        return returnedState;
    }

    /// @dev Check if a point is a valid Pallas point.
    /// @param point Pallas curve point
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

    /// @dev verifyFields() method from o1js.
    /// @param _signature The associated Schorr Signature
    /// @param _publicKey The pallas point (Public Key) of the signer
    /// @param _fields The fields array.
    /// @param _network False for 'testnet' and True for 'mainnet'
    function step_0_VF_assignValues(
        Point calldata _publicKey,
        Signature calldata _signature,
        uint256[] calldata _fields,
        bool _network
    ) external returns (uint256) {
        if (!isValidPublicKey(_publicKey)) revert InvalidPublicKey();

        uint256 toSetId = vfCounter;
        ++vfCounter;

        VerifyFieldsState storage toPush = vfLifeCycle[toSetId];
        toPush.atStep = 0;
        toPush.init = true;
        toPush.mainnet = _network;
        toPush.publicKey = _publicKey;
        toPush.signature = _signature;
        toPush.fields = _fields;

        vfLifeCycleCreator[toSetId] = msg.sender;

        return toSetId;
    }

    function step_1_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 0) revert StepSkipped();

        current.atStep = 1;
    }

    function step_2_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 1) revert StepSkipped();
        current.atStep = 2;
    }

    function step_3_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 2) revert StepSkipped();
        current.atStep = 3;
    }

    function step_4_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 3) revert StepSkipped();
        current.atStep = 4;
    }

    function step_5_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 4) revert StepSkipped();
        current.atStep = 5;
    }

    function step_6_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 5) revert StepSkipped();
        current.atStep = 6;
    }

    function step_7_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 6) revert StepSkipped();
        current.atStep = 7;
    }

    function step_0_VM_assignValues(
        Signature calldata _signature,
        Point calldata _publicKey,
        string calldata message
    ) external returns (uint256) {}

    // function step1_VM_prepareMessage(string calldata message) external {
    //     uint256 currentId = verificationCounter;
    //     ++verificationCounter;

    //     cleanupVerification(currentId);

    //     (, uint256 returnedMessageHash) = fromStringToHash(message);

    //     signatureLifeCycle[currentId].messageHash = returnedMessageHash;
    //     signatureLifeCycle[currentId].message = message;
    // }

    // function step2_prepareHashInput(
    //     uint256 verificationId,
    //     Point calldata publicKey,
    //     Signature calldata signature,
    //     uint256 r
    // ) public {
    //     VerificationState storage signatureLifeCycleObject = signatureLifeCycle[
    //         verificationId
    //     ];

    //     require(
    //         signatureLifeCycleObject.messageHash > 0,
    //         "No message fields found"
    //     );

    //     // uint256[] memory hashInput = new uint256[](4); // Length 4 for [messageField, pub.x, pub.y, r]
    //     signatureLifeCycleObject.hashInput[0] = signatureLifeCycle[
    //         verificationId
    //     ].messageHash;
    //     signatureLifeCycleObject.hashInput[1] = publicKey.x;
    //     signatureLifeCycleObject.hashInput[2] = publicKey.y;
    //     signatureLifeCycleObject.hashInput[3] = r;

    //     signatureLifeCycle[verificationId].atStep = 2;
    // }

    // function step3_computeHash(
    //     uint256 verificationId
    // ) public returns (uint256) {
    //     VerificationState storage signatureLifeCycleObject = signatureLifeCycle[
    //         verificationId
    //     ];

    //     require(
    //         signatureLifeCycleObject.atStep == 2,
    //         "Must complete step 2 first"
    //     );
    //     require(
    //         signatureLifeCycleObject.hashInput.length > 0,
    //         "No hash input found"
    //     );

    //     uint256[] memory hashInput = new uint256[](4);
    //     hashInput[0] = signatureLifeCycleObject.hashInput[0];
    //     hashInput[1] = signatureLifeCycleObject.hashInput[1];
    //     hashInput[2] = signatureLifeCycleObject.hashInput[2];
    //     hashInput[3] = signatureLifeCycleObject.hashInput[3];

    //     signatureLifeCycle[verificationId].hashInput;
    //     uint256 hashGenerated = hashPoseidonWithPrefix(
    //         SIGNATURE_PREFIX,
    //         hashInput
    //     );

    //     signatureLifeCycle[verificationId].hashGenerated = hashGenerated;
    //     signatureLifeCycle[verificationId].atStep = 3;

    //     console.log("Hash computed:", hashGenerated);
    //     return hashGenerated;
    // }

    // function step4_computeHP(
    //     uint256 verificationId,
    //     Point calldata publicKey
    // ) public returns (Point memory) {
    //     require(
    //         signatureLifeCycle[verificationId].atStep == 3,
    //         "Must complete step 3 first"
    //     );

    //     uint256 hashGenerated = signatureLifeCycle[verificationId]
    //         .hashGenerated;
    //     Point memory result = scalarMul(publicKey, hashGenerated);

    //     signatureLifeCycle[verificationId].hP = result;
    //     signatureLifeCycle[verificationId].atStep = 4;

    //     console.log("hP computed - x:", result.x, "y:", result.y);
    //     return result;
    // }

    // function step5_negatePoint(
    //     uint256 verificationId
    // ) public returns (Point memory) {
    //     require(
    //         signatureLifeCycle[verificationId].atStep == 4,
    //         "Must complete step 4 first"
    //     );

    //     Point memory hP = signatureLifeCycle[verificationId].hP;
    //     Point memory negHp = Point(hP.x, FIELD_MODULUS - hP.y);

    //     signatureLifeCycle[verificationId].negHp = negHp;
    //     signatureLifeCycle[verificationId].atStep = 5;

    //     return negHp;
    // }

    // function step6_computeSG(
    //     uint256 verificationId,
    //     uint256 s
    // ) public returns (Point memory) {
    //     require(
    //         signatureLifeCycle[verificationId].atStep == 5,
    //         "Must complete step 5 first"
    //     );

    //     Point memory G = Point(G_X, G_Y);
    //     Point memory sG = scalarMul(G, s);

    //     signatureLifeCycle[verificationId].sG = sG;
    //     signatureLifeCycle[verificationId].atStep = 6;

    //     console.log("sG computed - x:", sG.x, "y:", sG.y);
    //     return sG;
    // }

    // function step7_finalAddition(
    //     uint256 verificationId
    // ) public returns (Point memory) {
    //     require(
    //         signatureLifeCycle[verificationId].atStep == 6,
    //         "Must complete step 6 first"
    //     );

    //     Point memory sG = signatureLifeCycle[verificationId].sG;
    //     Point memory negHp = signatureLifeCycle[verificationId].negHp;

    //     Point memory result = addPoints(sG, negHp);

    //     signatureLifeCycle[verificationId].finalR = result;
    //     signatureLifeCycle[verificationId].atStep = 7;

    //     console.log("Final addition - x:", result.x, "y:", result.y);
    //     return result;
    // }

    // function step8_verify(
    //     uint256 verificationId,
    //     uint256 expectedR
    // ) public view returns (bool) {
    //     require(
    //         signatureLifeCycle[verificationId].atStep == 7,
    //         "Must complete step 7 first"
    //     );

    //     Point memory r = signatureLifeCycle[verificationId].finalR;

    //     console.log("Verifying...");
    //     console.log("Computed x:", r.x);
    //     console.log("Expected x:", expectedR);
    //     console.log("y value:", r.y);
    //     console.log("y mod 2:", r.y % 2);

    //     bool xMatches = r.x == expectedR;
    //     bool yIsEven = r.y % 2 == 0;

    //     console.log("x matches:", xMatches);
    //     console.log("y is even:", yIsEven);

    //     return xMatches && yIsEven;
    // }

    // function stringToCharacterArray(
    //     string memory str
    // ) internal pure returns (uint256[] memory) {
    //     bytes memory strBytes = bytes(str);
    //     uint256[] memory chars = new uint256[](strBytes.length);

    //     for (uint i = 0; i < strBytes.length; i++) {
    //         // Convert each character to its character code (equivalent to charCodeAt)
    //         chars[i] = uint256(uint8(strBytes[i]));
    //     }

    //     // Pad with null characters (value 0) up to maxLength if needed
    //     uint256[] memory paddedChars;
    //     if (chars.length < DEFAULT_STRING_LENGTH) {
    //         paddedChars = new uint256[](DEFAULT_STRING_LENGTH);
    //         for (uint i = 0; i < chars.length; i++) {
    //             paddedChars[i] = chars[i];
    //         }
    //         // Rest are initialized to 0 (null character)
    //     } else {
    //         paddedChars = chars;
    //     }

    //     return paddedChars;
    // }

    // struct Character {
    //     uint256 value;
    // }

    // struct CircuitString {
    //     Character[DEFAULT_STRING_LENGTH] values;
    // }

    // Character[DEFAULT_STRING_LENGTH] public testLatestCharactedGenerated;
    // uint256 public testLatestHash;

    // function getTestLatestCharacter()
    //     public
    //     view
    //     returns (Character[DEFAULT_STRING_LENGTH] memory)
    // {
    //     return testLatestCharactedGenerated;
    // }

    // // Main public interface - equivalent to CircuitString.fromString() in JS
    // function fromString(string memory str) public {
    //     bytes memory strBytes = bytes(str);
    //     require(
    //         strBytes.length <= DEFAULT_STRING_LENGTH,
    //         "CircuitString.fromString: input string exceeds max length!"
    //     );

    //     // Create and fill the character array
    //     Character[] memory chars = new Character[](DEFAULT_STRING_LENGTH);

    //     // Fill with actual characters
    //     for (uint i = 0; i < strBytes.length; i++) {
    //         chars[i] = Character(uint256(uint8(strBytes[i])));
    //         testLatestCharactedGenerated[i] = Character(
    //             uint256(uint8(strBytes[i]))
    //         );
    //     }

    //     // Fill remaining slots with null characters
    //     for (uint i = strBytes.length; i < DEFAULT_STRING_LENGTH; i++) {
    //         chars[i] = Character(0);
    //         testLatestCharactedGenerated[i] = Character(0);
    //     }
    // }

    // function hashCircuitString(
    //     Character[DEFAULT_STRING_LENGTH] calldata input
    // ) public {
    //     uint256[] memory values = new uint256[](DEFAULT_STRING_LENGTH);
    //     for (uint i = 0; i < input.length; i++) {
    //         values[i] = input[i].value;
    //     }

    //     testLatestHash = hashPoseidon(values);
    // }

    // function hash(
    //     uint256[DEFAULT_STRING_LENGTH] memory input
    // ) public view returns (uint256) {
    //     uint256[] memory values = new uint256[](DEFAULT_STRING_LENGTH);
    //     for (uint i = 0; i < input.length; i++) {
    //         values[i] = input[i];
    //     }

    //     return hashPoseidon(values);
    // }

    /// @dev Equivalent to CircuitString.from(str).hash() from o1js
    /// @param str The message string.
    /// @return charValues Character representation of a message string. Equivalent to CircuitString.from(str).
    /// @return charHash The generated hash. Equivalent to hash over a Field[].
    function fromStringToHash(
        string memory str
    ) internal view returns (uint256[] memory, uint256) {
        bytes memory strBytes = bytes(str);
        require(
            strBytes.length <= DEFAULT_STRING_LENGTH,
            "CircuitString.fromString: input string exceeds max length!"
        );

        uint256[] memory charValues = new uint256[](DEFAULT_STRING_LENGTH);

        for (uint i = 0; i < strBytes.length; i++) {
            charValues[i] = uint256(uint8(strBytes[i]));
        }
        for (uint i = strBytes.length; i < DEFAULT_STRING_LENGTH; i++) {
            charValues[i] = 0;
        }

        uint256 charHash = hashPoseidon(charValues);
        return (charValues, charHash);
    }
}
