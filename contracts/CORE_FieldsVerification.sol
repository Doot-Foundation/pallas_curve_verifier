// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./kimchi/Poseidon.sol";

error InvalidPublicKey();
error StepSkipped();

/**
 * @title PallasFieldsSignatureVerifier
 * @dev Verifies signatures over fields generated using mina-signer.
 */

contract PallasFieldsSignatureVerifier is Poseidon {
    struct VerifyMessageState {
        uint8 atStep;
        bool mainnet; // Added for network type
        Point publicKey;
        Signature signature;
        string message;
        string prefix; // Stored prefix as field element (step 1)
        uint256 messageHash; // For storing the computed hash
        Point pkInGroup; // Public key in group form
        Point sG; // s*G computation
        Point ePk; // e*pkInGroup computation
        Point R; // Final point
        bool isValid; // Final result
    }

    struct VerifyFieldsState {
        bool init; // To track if state was initialized
        bool mainnet; // Network flag
        uint8 atStep; // Current step tracker
        Point publicKey; // User provided public key
        Signature signature; // User provided signature
        uint256[] fields; // Fields to verify
        // Added intermediate computation states
        string prefix; // Stored prefix as field element (step 1)
        uint256 messageHash; // 'e' value computed from fields (step 2)
        Point pkInGroup; // Public key converted to curve point (step 3)
        Point sG; // Result of scalar multiplication s*G (step 4)
        Point ePk; // Result of scalar multiplication e*pkInGroup (step 5)
        Point R; // Final computed point R = sG - ePk (step 6)
        bool isValid; // Final verification result
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

    /// @notice Zero step - Input assignment and validation
    /// ==================================================
    /// References the first part of verify() in o1js:
    /// let { r, s } = signature;
    /// let pk = PublicKey.toGroup(publicKey);
    /// @param _publicKey The public key point (x,y)
    /// @param _signature Contains r (x-coordinate) and s (scalar)
    /// @param _fields Array of field elements to verify
    /// @param _network Network identifier (mainnet/testnet).
    /// Note for _network : It doesn't matter what we use since mina-signer uses 'testnet' regardless
    /// of the network set.
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
        toPush.prefix = "CodaSignature*******";

        vfLifeCycleCreator[toSetId] = msg.sender;

        return toSetId;
    }

    /// @notice Compute hash of the message with network prefix
    /// ==================================================
    /// Matches the first part of verify():
    /// let e = hashMessage(message, pk, r, networkId);
    /// Process:
    /// 1. Convert message to HashInput format
    /// 2. Append public key coordinates and signature.r
    /// 3. Apply network prefix and hash
    /// Order is critical: [message fields] + [pk.x, pk.y, sig.r]
    /// @param vfId id
    function step_1_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 0) revert StepSkipped();

        //let input = HashInput.append(message, { fields: [x, y, r] });
        uint256[] memory message = current.fields;
        uint256[] memory fullInput = new uint256[](message.length + 3);
        for (uint i = 0; i < message.length; i++) {
            fullInput[i] = message[i];
        }
        fullInput[message.length] = current.publicKey.x;
        fullInput[message.length + 1] = current.publicKey.y;
        fullInput[message.length + 2] = current.signature.r;

        current.messageHash = poseidonHashWithPrefix(current.prefix, fullInput);
        current.atStep = 1;
    }

    /// @notice Convert public key to curve point
    /// ==================================================
    /// From o1js: PublicKey.toGroup(publicKey)
    /// This converts compressed public key format (x, isOdd)
    /// to full curve point representation by:
    /// 1. Computing y² = x³ + 5 (Pallas curve equation)
    /// 2. Taking square root
    /// 3. Selecting appropriate y value based on isOdd
    function step_2_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 1) revert StepSkipped();

        // Create compressed point format from public key
        PointCompressed memory compressed = PointCompressed({
            x: current.publicKey.x,
            isOdd: (current.publicKey.y % 2 == 1)
        });

        // Convert to group point
        current.pkInGroup = _defaultToGroup(compressed);
        current.atStep = 2;
    }

    function step_3_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 2) revert StepSkipped();

        // Calculate s*G where G is generator point
        Point memory G = Point(G_X, G_Y);

        current.sG = scalarMul(G, current.signature.s);

        current.atStep = 3;
    }

    function step_4_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 3) revert StepSkipped();

        // Calculate e*pkInGroup where e is the message hash
        current.ePk = scalarMul(current.pkInGroup, current.messageHash);
        current.atStep = 4;
    }

    function step_5_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 4) revert StepSkipped();

        // R = sG - ePk
        current.R = addPoints(
            current.sG,
            Point(current.ePk.x, FIELD_MODULUS - current.ePk.y) // Negate ePk.y to subtract
        );
        // Note: R is already in affine coordinates due to addPoints implementation

        current.atStep = 5;
    }

    function step_6_VF(uint256 vfId) external isValidVFId(vfId) returns (bool) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 5) revert StepSkipped();

        // Final verification:
        // 1. Check R.x equals signature.r
        // 2. Check R.y is even
        current.isValid =
            (current.R.x == current.signature.r) &&
            isEven(current.R.y);
        current.atStep = 6;

        return current.isValid;
    }

    /// @dev verifyMessage()
    /// @param _signature The associated signature.
    /// @param _publicKey The public key.
    /// @param _message The string message
    /// @param _network Mainnet or testnet
    function step_0_VM_assignValues(
        Point calldata _publicKey,
        Signature calldata _signature,
        string calldata _message,
        bool _network
    ) external returns (uint256) {
        if (!isValidPublicKey(_publicKey)) revert InvalidPublicKey();

        uint256 toSetId = vmCounter;
        ++vmCounter;

        VerifyMessageState storage toPush = vmLifeCycle[toSetId];
        toPush.atStep = 0;
        toPush.publicKey = _publicKey;
        toPush.signature = _signature;
        toPush.message = _message;
        toPush.mainnet = _network;

        toPush.prefix = _network
            ? "MinaSignatureMainnet"
            : "CodaSignature*******";

        vmLifeCycleCreator[toSetId] = msg.sender;

        return toSetId;
    }

    function step_1_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 0) revert StepSkipped();

        // Use hashMessageLegacy for message path
        // current.messageHash = hashMessageLegacy(
        //     current.message,
        //     current.publicKey,
        //     current.signature.r,
        //     current.prefix
        // );

        current.atStep = 1;
    }

    function step_2_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 1) revert StepSkipped();

        // Create compressed point format from public key
        PointCompressed memory compressed = PointCompressed({
            x: current.publicKey.x,
            isOdd: (current.publicKey.y % 2 == 1)
        });

        // Convert to group point
        current.pkInGroup = _defaultToGroup(compressed);

        current.atStep = 2;
    }

    function step_3_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 2) revert StepSkipped();

        // Calculate s*G where G is generator point
        Point memory G = Point(G_X, G_Y); // From PallasConstants
        current.sG = scalarMul(G, current.signature.s);

        current.atStep = 3;
    }

    function step_4_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 3) revert StepSkipped();

        // Calculate e*pkInGroup where e is the message hash
        current.ePk = scalarMul(current.pkInGroup, current.messageHash);

        current.atStep = 4;
    }

    function step_5_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 4) revert StepSkipped();

        // R = sG - ePk
        current.R = addPoints(
            current.sG,
            Point(current.ePk.x, FIELD_MODULUS - current.ePk.y) // Negate ePk.y to subtract
        );

        current.atStep = 5;
    }

    function step_6_VM(uint256 vmId) external isValidVMId(vmId) returns (bool) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 5) revert StepSkipped();

        // Final verification:
        // 1. Check R.x equals signature.r
        // 2. Check R.y is even
        current.isValid =
            (current.R.x == current.signature.r) &&
            isEven(current.R.y);
        current.atStep = 6;

        return current.isValid;
    }

    /// @dev Equivalent to CircuitString.from(str).hash() from o1js
    /// @param str The message string.
    /// @return charValues Character representation of a message string. Equivalent to CircuitString.from(str).
    /// @return charHash The generated hash. Equivalent to hash over a Field[].
    function fromStringToHash(
        string memory str
    ) public view returns (uint256[] memory, uint256) {
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

        uint256 charHash = poseidonHash(charValues);
        return (charValues, charHash);
    }

    function groupToDefault(
        uint256 pointX,
        uint256 pointY
    ) public pure returns (uint256, bool) {
        // Just return a tuple without names
        bool isOdd = (pointY % 2 == 1);
        return (pointX, isOdd);
    }

    function defaultToGroup(
        uint256 pointX,
        bool isOdd
    ) external view returns (uint256[2] memory) {
        Point memory point = _defaultToGroup(
            PointCompressed({x: pointX, isOdd: isOdd})
        );
        return [point.x, point.y];
    }

    function _defaultToGroup(
        PointCompressed memory compressed
    ) internal view returns (Point memory) {
        uint256 _x = compressed.x; // x stays the same

        // y² = x³ + 5
        uint256 x2 = mulmod(_x, _x, FIELD_MODULUS);
        uint256 x3 = mulmod(x2, _x, FIELD_MODULUS);
        uint256 y2 = addmod(x3, BEQ, FIELD_MODULUS); // B is 5 for Pallas

        // Find square root
        uint256 _y = sqrtmod(y2, FIELD_MODULUS);

        // Check if we need to negate y based on isOdd
        bool computedIsOdd = (_y % 2 == 1);
        if (computedIsOdd != compressed.isOdd) {
            _y = FIELD_MODULUS - _y; // Negate y
        }

        return Point({x: _x, y: _y});
    }
}
