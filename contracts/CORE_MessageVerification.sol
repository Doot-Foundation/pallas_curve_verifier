// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./legacy/PoseidonLegacy.sol";

error InvalidPublicKey();
error StepSkipped();

/**
 * @title PallasMessageSignatureVerifier
 * @dev Verifies signatures over fields generated using mina-signer.
 */

contract PallasMessageSignatureVerifier is PoseidonLegacy {
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

    uint256 public vmCounter = 0;
    mapping(uint256 => address) public vmLifeCycleCreator;
    mapping(uint256 => VerifyMessageState) public vmLifeCycle;

    modifier isVMCreator(uint256 id) {
        require(msg.sender == vmLifeCycleCreator[id]);
        _;
    }

    modifier isValidVMId(uint256 id) {
        require(id < vmCounter);
        _;
    }

    function cleanupVMLifecycle(uint256 vmId) external isVMCreator(vmId) {
        delete vmLifeCycle[vmId];
    }

    function getVMState(
        uint256 vmId
    ) external view returns (VerifyMessageState memory state) {
        VerifyMessageState storage returnedState = vmLifeCycle[vmId];
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
        current.messageHash = hashMessageLegacy(
            current.message,
            current.publicKey,
            current.signature.r,
            current.prefix
        );

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
