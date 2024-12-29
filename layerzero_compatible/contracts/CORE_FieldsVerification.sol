// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./kimchi/Poseidon.sol";
import { OAppSender, MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error InvalidPublicKey();
error StepSkipped();

/**
 * @title PallasFieldsSignatureVerifier
 * @dev Verifies signatures over fields generated using mina-signer.
 */

contract PallasFieldsSignatureVerifier is Poseidon, OAppSender {
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

    /// Delegate and Owner to be set as address(0) after configuring for no interactions from anyone.
    constructor(
        address _endpoint, // LayerZero endpoint address
        address _delegate, // Address that can configure the OApp in the endpoint
        address _owner
    ) OAppCore(_endpoint, _delegate) Ownable(_owner) {}

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
    function getVFState(uint256 vfId) external view returns (VerifyFieldsState memory state) {
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
        return lhs == addmod(mulmod(x2, point.x, FIELD_MODULUS), 5, FIELD_MODULUS);
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

        current.messageHash = hashMessage(fields, publicKey, current.signature.r, current.prefix);
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

    function step_7_VF(uint256 vfId) external isValidVFId(vfId) {}

    /// @notice Converts a string to its character array representation and computes its Poseidon hash
    /// @dev Matches the behavior of CircuitString.from(str).hash() from o1js
    /// Process:
    /// 1. Converts string to fixed-length character array
    /// 2. Pads array with zeros if needed
    /// 3. Computes Poseidon hash of the array
    /// @param str The input string to convert and hash
    /// @return uint256[] Array of character values, padded to DEFAULT_STRING_LENGTH
    /// @return uint256 Poseidon hash of the character array
    function fromStringToHash(string memory str) public view returns (uint256[] memory, uint256) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length <= DEFAULT_STRING_LENGTH, "CircuitString.fromString: input string exceeds max length!");

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

    // -------------- LAYERZERO FTW --------------
    // -------------------------------------------

    // Original Data → optimize() → Optimized Data → pack() → Bytes for Transmission
    // (FieldsVerification) → (OptimizedFieldsVerification) → (bytes)

    /// @notice LayerZero message version
    uint16 private constant VERSION = 1;
    uint16 private DEST_CHAIN_ID;

    bytes32 private PEER;
    /// @notice Default gas limit for optimistic execution on destination chain
    uint256 private constant OPTIMISTIC_GAS = 100000;

    /// @notice Emitted when a verification is sent cross-chain
    /// @param payloadHash The keccak256 hash of the sent payload
    /// @param isFieldVerification True if this is a field verification, false if message verification
    event SingleVerificationSent(bytes32 indexed payloadHash, bool isFieldVerification);

    /// CONFIGURATION FUNCTIONS ------------------------------------
    // ChainId       : 42161
    // EndpointId    : 30110
    // EndpointV2    : 0x1a44076050125825900e736c501f859c50fE728c
    // SendUln302    : 0x975bcD720be66659e3EB3C0e4F1866a3020E493A
    // ReceiveUln302 : 0x7B9E184e07a6EE1aC23eAe0fe8D6Be2f663f05e6
    // LZ Executor   : 0x31CAe3B7fB82d847621859fb1585353c5720660D
    // LZ Dead DVN   : 0x758C419533ad64Ce9D3413BC8d3A97B026098EC1
    // const sendTx = await endpointContract.setSendLibrary(
    //   YOUR_OAPP_ADDRESS,
    //   remoteEid,
    //   YOUR_SEND_LIB_ADDRESS,
    // );

    function setConfig(uint32 _eid, uint32 _configType, bytes calldata _config) external onlyOwner {
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({ eid: _eid, configType: _configType, config: _config });

        endpoint.setConfig(address(this), address(0), params);
    }

    function setPeer(address _peer) external onlyOwner {
        PEER = bytes32(abi.encodePacked(_peer));
        _setPeer(DEST_CHAIN_ID, PEER);
    }

    function setDestChainId(uint16 _destChainId) external onlyOwner {
        DEST_CHAIN_ID = _destChainId;
    }

    /// @notice Converts a standard FieldsVerification into an optimized format for cross-chain transmission
    /// @param original The original FieldsVerification struct to optimize
    /// @return An OptimizedFieldsVerification struct with compressed data
    function optimizeFieldsVerification(
        FieldsVerification memory original
    ) internal pure returns (OptimizedFieldsVerification memory) {
        OptimizedFieldsVerification memory optimized;

        optimized.vfId = original.vfId; // Copy the ID
        optimized.isValid = original.isValid;

        optimized.fields = new bytes32[](original.fields.length);
        for (uint256 i = 0; i < original.fields.length; i++) {
            optimized.fields[i] = bytes32(original.fields[i]);
        }

        optimized.signature.r = bytes32(original.signature.r);
        optimized.signature.s = bytes32(original.signature.s);

        optimized.publicKey.x = bytes32(original.publicKey.x);
        optimized.publicKey.y = bytes32(original.publicKey.y);

        return optimized;
    }

    /// @notice Packs a field verification into bytes for cross-chain transmission
    /// @param verification The optimized verification struct to pack
    /// @return The packed bytes with a type identifier (1) followed by the verification data
    function packSingleFieldsVerification(
        OptimizedFieldsVerification memory verification
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(1), // type identifier for fields verification
                verification.vfId, // Add vfId to packed data
                verification.isValid,
                uint16(verification.fields.length),
                verification.fields,
                verification.signature.r,
                verification.signature.s,
                verification.publicKey.x,
                verification.publicKey.y
            );
    }

    /// @notice Sends a single field verification to another chain via LayerZero
    /// @param verification The verification data to send
    /// @dev Requires msg.value to cover LayerZero fees
    function sendSingleFieldsVerification(FieldsVerification calldata verification) external payable {
        OptimizedFieldsVerification memory optimized = optimizeFieldsVerification(verification);
        bytes memory payload = packSingleFieldsVerification(optimized);
        _sendPayload(payload, OPTIMISTIC_GAS);
        emit SingleVerificationSent(keccak256(payload), true);
    }

    /// @notice Internal function to send payload through LayerZero
    /// @param payload The encoded data to send
    /// @param gasLimit Gas limit for execution on destination chain
    /// @dev Uses VERSION for adapter parameters and optimistic execution
    function _sendPayload(bytes memory payload, uint256 gasLimit) internal {
        bytes memory options = abi.encodePacked(VERSION, gasLimit);
        MessagingFee memory fee = _quote(
            DEST_CHAIN_ID,
            payload,
            options,
            false // not paying in LZ token
        );

        _lzSend(DEST_CHAIN_ID, payload, options, fee, payable(msg.sender));
    }

    function oAppVersion() public pure override returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1);
    }
}
