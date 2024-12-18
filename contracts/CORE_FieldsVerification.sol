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
    /// @title Verify Fields State Structure
    /// @notice Holds the state for field array signature verification process
    /// @dev Used to track the progress and store intermediate results during verification
    struct VerifyFieldsState {
        /// @notice Indicates if the state has been properly initialized
        bool init;
        /// @notice Network flag - true for mainnet, false for testnet
        bool mainnet;
        /// @notice Final verification result
        bool isValid;
        /// @notice Tracks the current step of verification (0-6)
        uint8 atStep;
        /// @notice The public key point (x,y) being verified against
        Point publicKey;
        /// @notice The signature containing r (x-coordinate) and s (scalar)
        Signature signature;
        /// @notice Hash of the fields array with prefix ('e' value)
        uint256 messageHash;
        /// @notice Public key converted to curve point format
        Point pkInGroup;
        /// @notice Result of scalar multiplication s*G
        Point sG;
        /// @notice Result of scalar multiplication e*pkInGroup
        Point ePk;
        /// @notice Final computed point R = sG - ePk
        Point R;
        /// @notice Network-specific prefix for message hashing
        string prefix;
        /// @notice Array of field elements to verify
        uint256[] fields;
    }

    // uint256 private constant EVEN_CHECK_MASK = 1;

    /// @notice Counter for tracking total number of field verification processes
    /// @dev Incremented for each new verification process
    uint256 public vfCounter = 0;

    /// @notice Maps verification IDs to their creators' addresses
    /// @dev Used for access control in cleanup operations
    mapping(uint256 => address) public vfLifeCycleCreator;

    /// @notice Maps verification IDs to their respective state structures
    /// @dev Main storage for verification process states
    mapping(uint256 => VerifyFieldsState) public vfLifeCycle;

    /// @notice Ensures only the creator of a verification process can access it
    /// @param id The verification process ID
    modifier isVFCreator(uint256 id) {
        if (msg.sender != vfLifeCycleCreator[id]) revert();
        _;
    }

    /// @notice Ensures the verification ID exists
    /// @param id The verification process ID to check
    modifier isValidVFId(uint256 id) {
        if (id >= vfCounter) revert();
        _;
    }

    /// @notice Removes a verification process state from storage
    /// @dev Can only be called by the creator of the verification process
    /// @param vfId The ID of the verification process to clean up
    function cleanupVFLifecycle(uint256 vfId) external isVFCreator(vfId) {
        delete vfLifeCycle[vfId];
    }

    /// @notice Retrieves the complete state of a field verification process
    /// @dev Returns a copy of the state, not a reference
    /// @param vfId The ID of the verification process
    /// @return state The complete verification state structure
    function getVFState(
        uint256 vfId
    ) external view returns (VerifyFieldsState memory state) {
        return vfLifeCycle[vfId];
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
        return
            lhs == addmod(mulmod(x2, point.x, FIELD_MODULUS), 5, FIELD_MODULUS);
    }

    /// @notice Zero step - Input assignment.
    /// ==================================================
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

        uint256 toSetId = vfCounter++;

        VerifyFieldsState storage toPush = vfLifeCycle[toSetId];
        // Pack initialization in optimal order
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
        if (!current.init) revert("Not initialized");

        // Cache fields array to avoid multiple storage reads
        uint256[] memory fields = current.fields;
        Point memory publicKey = current.publicKey;

        current.messageHash = hashMessage(
            fields,
            publicKey,
            current.signature.r,
            current.prefix
        );
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

        // Cache public key to avoid multiple storage reads
        uint256 pubKeyX = current.publicKey.x;
        uint256 pubKeyY = current.publicKey.y;

        current.pkInGroup = _defaultToGroup(
            PointCompressed({x: pubKeyX, isOdd: (pubKeyY & 1 == 1)})
        );
        current.atStep = 2;
    }

    /// @notice Compute s*G where G is generator point
    /// ==================================================
    /// From o1js: scale(one, s)
    /// Critical: Do not reduce scalar by SCALAR_MODULUS
    /// Uses projective coordinates internally for efficiency
    /// Must use exact generator point coordinates from o1js:
    /// G.x = 1
    /// G.y = 0x1b74b5a30a12937c53dfa9f06378ee548f655bd4333d477119cf7a23caed2abb
    function step_3_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
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
    function step_4_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
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
    function step_5_VF(uint256 vfId) external isValidVFId(vfId) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 4) revert StepSkipped();

        Point memory sG = current.sG;
        Point memory ePk = current.ePk;

        current.R = addPoints(sG, Point(ePk.x, FIELD_MODULUS - ePk.y));
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
    /// Returns final verification result
    function step_6_VF(uint256 vfId) external isValidVFId(vfId) returns (bool) {
        VerifyFieldsState storage current = vfLifeCycle[vfId];
        if (current.atStep != 5) revert StepSkipped();

        // Cache values and compute in memory
        Point memory R = current.R;
        uint256 sigR = current.signature.r;

        current.isValid = (R.x == sigR) && (R.y & 1 == 0);
        current.atStep = 6;

        return current.isValid;
    }

    /// @notice Converts a string to its character array representation and computes its Poseidon hash
    /// @dev Matches the behavior of CircuitString.from(str).hash() from o1js
    /// Process:
    /// 1. Converts string to fixed-length character array
    /// 2. Pads array with zeros if needed
    /// 3. Computes Poseidon hash of the array
    /// @param str The input string to convert and hash
    /// @return uint256[] Array of character values, padded to DEFAULT_STRING_LENGTH
    /// @return uint256 Poseidon hash of the character array
    function fromStringToHash(
        string memory str
    ) public view returns (uint256[] memory, uint256) {
        bytes memory strBytes = bytes(str);
        require(
            strBytes.length <= DEFAULT_STRING_LENGTH,
            "CircuitString.fromString: input string exceeds max length!"
        );

        uint256[] memory charValues = new uint256[](DEFAULT_STRING_LENGTH);

        // Convert string characters to their numeric values
        for (uint i = 0; i < strBytes.length; i++) {
            charValues[i] = uint256(uint8(strBytes[i]));
        }
        // Pad remaining slots with zeros
        for (uint i = strBytes.length; i < DEFAULT_STRING_LENGTH; i++) {
            charValues[i] = 0;
        }

        uint256 charHash = poseidonHash(charValues);
        return (charValues, charHash);
    }

    /// @notice Converts a compressed point to its full curve point representation
    /// @dev Implements point decompression for Pallas curve (y² = x³ + 5)
    /// Process:
    /// 1. Keep x-coordinate from compressed point
    /// 2. Calculate y² using curve equation (y² = x³ + 5)
    /// 3. Compute square root to get y value
    /// 4. Choose correct y value based on oddness flag
    /// @param compressed The compressed point containing x-coordinate and oddness flag
    /// @return Point Complete point with both x and y coordinates on Pallas curve
    function _defaultToGroup(
        PointCompressed memory compressed
    ) internal view returns (Point memory) {
        uint256 _x = compressed.x;

        uint256 x2 = mulmod(_x, _x, FIELD_MODULUS);
        uint256 y2 = addmod(mulmod(x2, _x, FIELD_MODULUS), BEQ, FIELD_MODULUS);

        uint256 _y = sqrtmod(y2, FIELD_MODULUS);

        if ((_y & 1 == 1) != compressed.isOdd) {
            _y = FIELD_MODULUS - _y;
        }

        return Point({x: _x, y: _y});
    }
}
