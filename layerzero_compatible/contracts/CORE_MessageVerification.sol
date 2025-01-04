// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./legacy/PoseidonLegacy.sol";

error InvalidPublicKey();
error StepSkipped();

/**
 * @title PallasMessageSignatureVerifier
 * @dev Verifies signatures over message generated using mina-signer.
 */

contract PallasMessageSignatureVerifier is PoseidonLegacy {
    /// @notice Identifier for the type of verification.
    uint8 constant TYPE_VERIFY_MESSAGE = 1;

    /// @notice Counter for tracking total number of verification processes
    /// @dev Used as a unique ID. Incremented for each new verification process
    uint256 public vmCounter = 0;

    /// @notice Maps verification IDs to their creators' addresses
    /// @dev Used for access control in cleanup operations
    mapping(uint256 => address) public vmLifeCycleCreator;

    /// @notice Maps verification IDs to their respective state structures
    /// @dev Main storage for verification process states
    mapping(uint256 => VerifyMessageState) public vmLifeCycle;

    /// @notice Maps verification IDs to their respective state structures compressed into bytes form.
    /// Doesn't store intermediate states but only the important bits.
    mapping(uint256 => bytes) public vmLifeCycleBytesCompressed;

    /// @notice Ensures only the creator of a verification process can access it
    /// @param vmId The verification process ID
    modifier isVMCreator(uint256 vmId) {
        if (msg.sender != vmLifeCycleCreator[vmId]) revert();
        _;
    }

    /// @notice Ensures the verification ID exists
    /// @param vmId The verification process ID to check
    modifier isValidVMId(uint256 vmId) {
        if (vmId >= vmCounter) revert();
        _;
    }

    /// @notice Removes a verification process state from storage
    /// @dev Can only be called by the creator of the verification process
    /// @param vmId The ID of the verification process to clean up
    function cleanupVMLifecycle(uint256 vmId) external isVMCreator(vmId) {
        delete vmLifeCycle[vmId];
    }

    /// @notice Retrieves the complete state of a verification process
    /// @dev Returns a copy of the state, not a reference
    /// @param vmId The ID of the verification process
    /// @return state The complete verification state structure
    function getVMState(uint256 vmId) external view returns (VerifyMessageState memory state) {
        return vmLifeCycle[vmId];
    }

    /// @notice Retrieves the complete state of a verification process in bytes
    /// @param vmId The ID of the verification process
    /// @return state The complete verification state structure in bytes
    function getVMStateBytesCompressed(uint256 vmId) external view returns (bytes memory) {
        return vmLifeCycleBytesCompressed[vmId];
    }

    /// @notice Decodes a compressed byte array into a VerifyMessageStateCompressed struct
    /// @param data The compressed bytes containing all VM state fields. Expected minimum length is 195 bytes
    ///             plus additional bytes for the dynamic message string
    /// @return state The decoded VerifyMessageStateCompressed struct containing:
    ///               - verifyType (1 byte)
    ///               - vmId (32 bytes)
    ///               - mainnet flag (1 byte)
    ///               - isValid flag (1 byte)
    ///               - publicKey (x,y coordinates, 64 bytes)
    ///               - signature (r,s values, 64 bytes)
    ///               - messageHash (32 bytes)
    ///               - prefix (network-dependent string)
    ///               - message (dynamic string starting at byte 195)
    /// @dev The prefix is set conditionally based on the mainnet flag:
    ///      - mainnet=true: "MinaSignatureMainnet"
    ///      - mainnet=false: "CodaSignature*******"
    function decodeVMStateBytesCompressed(
        bytes calldata data
    ) external pure returns (VerifyMessageStateCompressed memory state) {
        state.verifyType = uint8(data[0]);
        state.vmId = uint256(bytes32(data[1:33]));
        state.mainnet = (data[33] != 0);
        state.isValid = (data[34] != 0);

        uint256 x;
        uint256 y;
        uint256 r;
        uint256 s;
        uint256 messageHash;

        assembly {
            // Load all values first
            x := calldataload(add(data.offset, 35))
            y := calldataload(add(data.offset, 67))
            r := calldataload(add(data.offset, 99))
            s := calldataload(add(data.offset, 131))
            messageHash := calldataload(add(data.offset, 163))
        }

        // Then assign to struct fields
        state.publicKey.x = x;
        state.publicKey.y = y;
        state.signature.r = r;
        state.signature.s = s;
        state.messageHash = messageHash;
        state.prefix = state.mainnet ? "MinaSignatureMainnet" : "CodaSignature*******";

        state.message = abi.decode(data[195:], (string));
        return state;
    }

    /// @notice Validates if a point lies on the Pallas curve
    /// @dev Checks if the point coordinates satisfy the curve equation y² = x³ + 5
    /// @param point The point to validate with x and y coordinates
    /// @return bool True if the point lies on the curve, false otherwise
    function isValidPublicKey(Point memory point) public pure returns (bool) {
        if (point.x >= FIELD_MODULUS || point.y >= FIELD_MODULUS) {
            return false;
        }

        uint256 x2 = mulmod(point.x, point.x, FIELD_MODULUS);
        uint256 lhs = mulmod(point.y, point.y, FIELD_MODULUS);
        return lhs == addmod(mulmod(x2, point.x, FIELD_MODULUS), 5, FIELD_MODULUS);
    }

    /// @notice Zero step - Input assignment for message verification
    /// ==================================================
    /// Initializes the verification state for a message signature
    /// @param publicKey The public key point (x,y)
    /// @param signature Contains r (x-coordinate) and s (scalar)
    /// @param message The string message to verify
    /// @param network Network identifier (true for mainnet, false for testnet)
    function step_0_VM_assignValues(
        Point calldata publicKey,
        Signature calldata signature,
        string calldata message,
        bool network
    ) external returns (uint256) {
        if (!isValidPublicKey(publicKey)) revert InvalidPublicKey();

        uint256 toSetId = vmCounter;
        ++vmCounter;

        VerifyMessageState storage toPush = vmLifeCycle[toSetId];
        toPush.atStep = 0;
        toPush.publicKey = publicKey;
        toPush.signature = signature;
        toPush.message = message;
        toPush.mainnet = network;
        toPush.init = true;

        toPush.prefix = network ? "MinaSignatureMainnet" : "CodaSignature*******";

        vmLifeCycleCreator[toSetId] = msg.sender;

        return toSetId;
    }

    /// @notice Compute hash of the message with network prefix
    /// ==================================================
    /// Matches the first part of verify():
    /// let e = hashMessage(message, pk, r, networkId)
    /// Process:
    /// 1. Convert string message to bytes
    /// 2. Append public key coordinates and signature.r
    /// 3. Apply network prefix and hash
    /// @param vmId Verification state identifier
    function step_1_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 0) revert StepSkipped();
        if (!current.init) revert("Not initialized");

        // Cache values to reduce storage reads
        string memory message = current.message;
        Point memory publicKey = current.publicKey;
        uint256 sigR = current.signature.r;
        string memory prefix = current.prefix;

        current.messageHash = hashMessageLegacy(message, publicKey, sigR, prefix);
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
    /// @param vmId Verification state identifier
    function step_2_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 1) revert StepSkipped();

        uint256 pubKeyX = current.publicKey.x;
        uint256 pubKeyY = current.publicKey.y;

        current.pkInGroup = _defaultToGroup(PointCompressed({ x: pubKeyX, isOdd: (pubKeyY & 1 == 1) }));

        current.atStep = 2;
    }

    /// @notice Compute s*G where G is generator point
    /// ==================================================
    /// From o1js: scale(one, s)
    /// Critical: Do not reduce scalar by SCALAR_MODULUS
    /// Uses projective coordinates internally for efficiency
    /// Must use exact generator point coordinates from o1js:
    /// G.x = 1
    /// G.y = specific value from PallasConstants
    /// @param vmId Verification state identifier
    function step_3_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 2) revert StepSkipped();

        Point memory G = Point(G_X, G_Y);
        current.sG = scalarMul(G, current.signature.s);
        current.atStep = 3;
    }

    /// @notice Compute e*publicKey
    /// ==================================================
    /// From o1js: scale(Group.toProjective(pk), e)
    /// where e is the message hash computed in step 1
    /// Uses same scalar multiplication as s*G
    /// Takes public key point from step 2
    /// @param vmId Verification state identifier
    function step_4_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 3) revert StepSkipped();

        Point memory pkInGroup = current.pkInGroup;
        uint256 messageHash = current.messageHash;

        current.ePk = scalarMul(pkInGroup, messageHash);
        current.atStep = 4;
    }

    /// @notice Compute R = sG - ePk
    /// ==================================================
    /// From o1js: sub(scale(one, s), scale(Group.toProjective(pk), e))
    /// Implemented as point addition with negated ePk
    /// Point negation on Pallas: (x, -y)
    /// R will be used for final verification
    /// @param vmId Verification state identifier
    function step_5_VM(uint256 vmId) external isValidVMId(vmId) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 4) revert StepSkipped();

        uint256 negY;
        unchecked {
            negY = FIELD_MODULUS - current.ePk.y;
        }

        current.R = addPoints(current.sG, Point(current.ePk.x, negY));
        current.atStep = 5;
    }

    /// @notice Final signature verification
    /// ==================================================
    /// From o1js:
    /// let { x: rx, y: ry } = Group.fromProjective(R);
    /// return Field.isEven(ry) && Field.equal(rx, r);
    /// Two conditions must be met:
    /// 1. R.x equals signature.r
    /// 2. R.y is even
    /// @param vmId Verification state identifier
    /// @return bool True if signature is valid, false otherwise
    function step_6_VM(uint256 vmId) external isValidVMId(vmId) returns (bool) {
        VerifyMessageState storage current = vmLifeCycle[vmId];
        if (current.atStep != 5) revert StepSkipped();

        Point memory R = current.R;
        uint256 sigR = current.signature.r;

        current.isValid = (R.x == sigR) && (R.y & 1 == 0);
        current.atStep = 6;

        bytes memory stateBytesCompressed = packVerifyMessageStateCompressed(current, vmId);
        vmLifeCycleBytesCompressed[vmId] = stateBytesCompressed;

        return current.isValid;
    }

    /// @notice Packs a VerifyMessageState into a compressed bytes format for efficient storage
    /// @dev Combines fixed-length data with the dynamic message string using abi.encodePacked and abi.encode
    /// @param state The VerifyMessageState to be compressed
    /// @param vmId The unique identifier for this message verification state
    /// @return bytes The packed binary representation of the state
    function packVerifyMessageStateCompressed(
        VerifyMessageState memory state,
        uint256 vmId
    ) public pure returns (bytes memory) {
        bytes memory fixedData = abi.encodePacked(
            TYPE_VERIFY_MESSAGE,
            vmId,
            state.mainnet,
            state.isValid,
            state.publicKey.x,
            state.publicKey.y,
            state.signature.r,
            state.signature.s,
            state.messageHash
        );

        return abi.encodePacked(fixedData, abi.encode(state.message));
    }

    /// @notice Converts a compressed point to its full curve point representation
    /// @dev Implements point decompression for Pallas curve (y² = x³ + 5)
    /// Process:
    /// 1. Calculate y² using curve equation
    /// 2. Find square root of y²
    /// 3. Choose correct y value based on oddness flag
    /// @param compressed The compressed point containing x-coordinate and oddness flag
    /// @return Point Complete point with both x and y coordinates
    function _defaultToGroup(PointCompressed memory compressed) internal view returns (Point memory) {
        uint256 _x = compressed.x;

        uint256 x2 = mulmod(_x, _x, FIELD_MODULUS);
        uint256 y2 = addmod(mulmod(x2, _x, FIELD_MODULUS), BEQ, FIELD_MODULUS);

        uint256 _y = sqrtmod(y2, FIELD_MODULUS);

        if ((_y & 1 == 1) != compressed.isOdd) {
            _y = FIELD_MODULUS - _y;
        }

        return Point({ x: _x, y: _y });
    }
}
