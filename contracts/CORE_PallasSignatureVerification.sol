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
        bool mainnet; // Added for network type
        Point publicKey;
        Signature signature;
        string message;
        uint256[] charValues; // For storing the character array
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

    /// @dev verifyFields() method from o1js.
    /// @param _publicKey The pallas point (Public Key) of the signer
    /// @param _signature The associated Schorr Signature
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
        toPush.prefix = "CodaSignature*******";

        vfLifeCycleCreator[toSetId] = msg.sender;

        return toSetId;
    }

    /// ==================================================
    /// hashMessage(message, pk, r, networkId)
    /// ==================================================
    /// message : { fields: data }
    /// pk : PublicKey in Group representation : {x,y}
    /// r : Field from Signature
    /// networkId is fixed to 'testnet'
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
    /// @param message The string message
    function step_0_VM_assignValues(
        Signature calldata _signature,
        Point calldata _publicKey,
        string calldata message
    ) external returns (uint256) {
        if (!isValidPublicKey(_publicKey)) revert InvalidPublicKey();

        uint256 toSetId = vmCounter;
        ++vmCounter;

        VerifyMessageState storage toPush = vmLifeCycle[toSetId];
        toPush.atStep = 0;
        toPush.publicKey = _publicKey;
        toPush.signature = _signature;
        toPush.message = message;

        vmLifeCycleCreator[toSetId] = msg.sender;

        return toSetId;
    }

    function step_1_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 0) revert StepSkipped();

        // Convert string to character array using fromStringToHash
        uint256[] memory charValues;
        uint256 hashUint;
        (charValues, hashUint) = fromStringToHash(current.message);

        current.charValues = charValues;
        current.messageHash = hashUint; // Store the hash too

        current.atStep = 1;
    }

    function step_2_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 1) revert StepSkipped();

        // Network prefix
        string memory prefix = current.mainnet
            ? "MinaSignatureMainnet"
            : "CodaSignature*******";

        // Hash with prefix
        current.messageHash = poseidonHashWithPrefix(
            prefix,
            current.charValues
        );

        current.atStep = 2;
    }

    function step_3_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 2) revert StepSkipped();

        // Create compressed point format from public key
        PointCompressed memory compressed = PointCompressed({
            x: current.publicKey.x,
            isOdd: (current.publicKey.y % 2 == 1)
        });

        // Convert to group point
        current.pkInGroup = _defaultToGroup(compressed);

        current.atStep = 3;
    }

    function step_4_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 3) revert StepSkipped();

        // Calculate s*G where G is generator point
        Point memory G = Point(G_X, G_Y); // From PallasConstants
        current.sG = scalarMul(G, current.signature.s);

        current.atStep = 4;
    }

    function step_5_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 4) revert StepSkipped();

        // Calculate e*pkInGroup where e is the message hash
        current.ePk = scalarMul(current.pkInGroup, current.messageHash);

        current.atStep = 5;
    }

    function step_6_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 5) revert StepSkipped();

        // R = sG - ePk
        current.R = addPoints(
            current.sG,
            Point(current.ePk.x, FIELD_MODULUS - current.ePk.y) // Negate ePk.y to subtract
        );

        current.atStep = 6;
    }

    function step_7_VM(uint256 vmId) external isValidVMId(vmId) returns (bool) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 6) revert StepSkipped();

        // Final verification:
        // 1. Check R.x equals signature.r
        // 2. Check R.y is even
        current.isValid =
            (current.R.x == current.signature.r) &&
            isEven(current.R.y);
        current.atStep = 7;

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
        uint256 y2 = addmod(x3, B, FIELD_MODULUS); // B is 5 for Pallas

        // Find square root
        uint256 _y = sqrtmod(y2, FIELD_MODULUS);

        // Check if we need to negate y based on isOdd
        bool computedIsOdd = (_y % 2 == 1);
        if (computedIsOdd != compressed.isOdd) {
            _y = FIELD_MODULUS - _y; // Negate y
        }

        return Point({x: _x, y: _y});
    }

    // function groupToDefault(
    //     uint256 x,
    //     uint256 y
    // ) public pure returns (uint256 x_, bool isOdd) {
    //     // Return named tuple instead of array
    //     isOdd = (y % 2 == 1);
    //     x_ = x;
    // }
}
