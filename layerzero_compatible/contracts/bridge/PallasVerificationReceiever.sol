// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ICORE_FieldsVerification.sol";
import "../interfaces/ICORE_MessageVerification.sol";

import "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import { OAppRead } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import { Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
/// ETHEREUM MAINNET
/// Channel Ids : 4294967295, 4294967294
/// ReadLib1002 (Origin Chain Library) : 0x74F55Bc2a79A27A0bF1D1A35dB5d0Fc36b9FDB9D
/// Origin Chain DVN : 0x1e129c36bc3afc3f0d46a42c9d9cab7586bda94c

// Decide which lzRead compatible DVNs support your target chains.
// Deploy an lzRead compatible OApp.
// Set your application's send and receive library to ReadLib1002 via endpoint.setSendLibrary() and endpoint.setReceiveLibrary().
// Set your application's DVN Config via endpoint.setConfig().

struct ChainConfig {
    uint16 confirmations;
    address toReadFrom;
}

contract PallasVerificationReceiever is OAppRead {
    address verifyFieldsContract = address(0);
    address verifyMessageContract = address(0);
    string constant MAINNET_PREFIX = "MinaSignatureMainnet";
    string constant TESTNET_PREFIX = "CodaSignature*******";
    uint8 constant TYPE_VERIFY_MESSAGE = 1;
    uint8 constant TYPE_VERIFY_FIELDS = 2;
    uint8 internal constant MAP_ONLY = 0;
    uint8 internal constant REDUCE_ONLY = 1;
    uint8 internal constant MAP_AND_REDUCE = 2;
    uint8 internal constant NONE = 3;
    uint32 constant READ_CHANNEL_EID_THRESHOLD = 4294965694;
    uint32 constant ETH_READ_CHANNEL = 4294967295;
    uint32 constant ARB_ENDPOINT_ID = 30110;
    uint32 constant ETH_ENDPOINT_ID = 30101;
    ChainConfig CHAIN_CONFIG_VF = ChainConfig({ confirmations: 3, toReadFrom: verifyFieldsContract });
    ChainConfig CHAIN_CONFIG_VM = ChainConfig({ confirmations: 3, toReadFrom: verifyMessageContract });

    mapping(uint256 => VerifyFieldsStateCompressed) vfIdToData;
    mapping(uint256 => VerifyMessageStateCompressed) vmIdToData;

    ICORE_FieldsVerification public fvContract = ICORE_FieldsVerification(address(0));
    ICORE_MessageVerification public mvContract = ICORE_MessageVerification(address(0));

    event ArbitraryMessageReceived(Origin, bytes);

    constructor(address _endpoint, address _delegate) OAppRead(_endpoint, _delegate) Ownable(_delegate) {}

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function unpackVerifyMessageState(
        bytes calldata data
    ) internal pure returns (uint256 id, VerifyMessageStateCompressed memory state) {
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
        state.prefix = "CodaSignature*******";

        state.message = abi.decode(data[195:], (string));
        return (state.vmId, state);
    }

    function unpackVerifyFieldsState(
        bytes calldata data
    ) internal pure returns (uint256 id, VerifyFieldsStateCompressed memory state) {
        state.verifyType = uint8(data[0]);
        state.vfId = uint256(bytes32(data[1:33]));
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
        state.prefix = "CodaSignature*******";

        state.fields = abi.decode(data[195:], (uint256[]));
        return (state.vfId, state);
    }

    function readGetBytesCompressed(
        uint8 verifyType,
        uint32 calldataSize,
        uint128 gasLimit,
        uint256 id
    ) external payable returns (MessagingReceipt memory receipt) {
        /**
         * @dev Internal function to interact with the LayerZero EndpointV2.send() for sending a message.
         * @param _dstEid The destination endpoint ID.
         * @param _message The message payload.
         * @param _options Additional options for the message.
         * @param _fee The calculated LayerZero fee for the message.
         *      - nativeFee: The native fee.
         *      - lzTokenFee: The lzToken fee.
         * @param _refundAddress The address to receive any excess fee values sent to the endpoint.
         * @return receipt The receipt for the sent message.
         *      - guid: The unique identifier for the sent message.
         *      - nonce: The nonce of the sent message.
         *      - fee: The LayerZero fee incurred for the message.
         */
        bytes memory _cmd = getCmd(verifyType, id);
        /// @dev GAS_LIMIT, CALLDATA_SIZE, MSG_VALUE - Default : 100_000, 64, 0
        /// @dev This send parameter allows you to deliver an amount of gasLimit automatically to
        /// endpoint.lzReceive from your configured Executor.
        /// @dev An additional requirement for _options is to profile the calldata size of your returned data type.
        bytes memory _options = OptionsBuilder.newOptions();
        _options = OptionsBuilder.addExecutorLzReadOption(_options, gasLimit, calldataSize, 0);
        return _lzSend(ETH_READ_CHANNEL, _cmd, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    function getCmd(uint8 verifyType, uint256 id) public view returns (bytes memory) {
        bytes memory callData;
        if (verifyType == TYPE_VERIFY_MESSAGE)
            callData = abi.encodeWithSelector(ICORE_MessageVerification.getVMStateBytesCompressed.selector, id);
        else if (verifyType == TYPE_VERIFY_FIELDS)
            callData = abi.encodeWithSelector(ICORE_FieldsVerification.getVFStateBytesCompressed.selector, id);

        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        if (verifyType == TYPE_VERIFY_FIELDS) {
            readRequests[0] = EVMCallRequestV1({
                appRequestLabel: uint16(1),
                targetEid: ARB_ENDPOINT_ID,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: CHAIN_CONFIG_VF.confirmations,
                to: CHAIN_CONFIG_VF.toReadFrom,
                callData: callData
            });
        } else {
            readRequests[0] = EVMCallRequestV1({
                appRequestLabel: uint16(1),
                targetEid: ARB_ENDPOINT_ID,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: CHAIN_CONFIG_VM.confirmations,
                to: CHAIN_CONFIG_VM.toReadFrom,
                callData: callData
            });
        }

        EVMCallComputeV1 memory computeSettings = EVMCallComputeV1({
            computeSetting: NONE,
            targetEid: ETH_ENDPOINT_ID,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 3,
            to: address(this)
        });

        return ReadCodecV1.encode(0, readRequests, computeSettings);
    }

    /// @notice Internal function to handle incoming messages and read responses.
    /// @dev Filters messages based on `srcEid` to determine the type of incoming data.
    /// @param _origin The origin information containing the source Endpoint ID (`srcEid`).
    /// @param _guid The unique identifier for the received message.
    /// @param _message The encoded message data.
    /// @param _executor The executor address.
    /// @param _extraData Additional data.
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual override {
        if (_origin.srcEid > READ_CHANNEL_EID_THRESHOLD) {
            _readLzReceive(_origin, _guid, _message, _executor, _extraData);
        } else {
            emit ArbitraryMessageReceived(_origin, _message);
        }
    }

    /// @notice Internal function to handle lzRead responses.
    /// @dev _origin The origin information (unused in this implementation).
    /// @dev _guid The unique identifier for the received message (unused in this implementation).
    /// @param _message The encoded message data.
    /// @dev _executor The executor address (unused in this implementation).
    /// @dev _extraData Additional data (unused in this implementation).
    function _readLzReceive(
        Origin calldata /* _origin */,
        bytes32 /* _guid */,
        bytes calldata _message,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) internal virtual {
        uint8 verifyType = uint8(_message[0]);

        if (verifyType == TYPE_VERIFY_FIELDS) {
            (uint256 id, VerifyFieldsStateCompressed memory state) = unpackVerifyFieldsState(_message);
            vfIdToData[id] = state;
        } else {
            (uint256 id, VerifyMessageStateCompressed memory state) = unpackVerifyMessageState(_message);
            vmIdToData[id] = state;
        }
    }
}
