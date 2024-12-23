
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
