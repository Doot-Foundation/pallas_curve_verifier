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

/// @title ChainConfig
/// @notice Configuration structure for chain-specific settings
/// @param confirmations Number of confirmations required
/// @param toReadFrom Address to read from
struct ChainConfig {
    uint16 confirmations;
    address toReadFrom;
}

/// @notice Structure to hold quote calculation results
/// @param gasLimit Gas limit for the transaction
/// @param calldataSize Size of the calldata
/// @param nativeFee Fee in native currency
/// @param lzTokenFee Fee in LayerZero tokens
struct QuoteResult {
    uint128 gasLimit;
    uint32 calldataSize;
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct ModeConfig {
    uint128 gasLimit;
    uint32 messageSize;
    uint32 fieldsSize;
}

/// @notice To decide the type incoming read bytes.
enum TYPE {
    VERIFY_PLACEHOLDER_DO_NOT_USE,
    VERIFY_MESSAGE,
    VERIFY_FIELDS
}

/// @notice Type of automatic modes. Used in read config.
enum MODE {
    CONSERVATIVE,
    DEFAULT,
    OPTIMISTIC
}

/// @notice Error thrown when the provided fee is insufficient
/// @param required The required fee amount
/// @param provided The provided fee amount
error InsufficientFee(uint256 required, uint256 provided);

/// @title PallasVerificationReceiever
/// @notice Contract for receiving and processing cross-chain verification data
/// @dev Inherits from OAppRead for cross-chain messaging and Ownable for access control
contract PallasVerificationReceiever is OAppRead {
    /// @notice Address of the contract for field verification
    address VERIFY_FIELDS_CONTRACT = address(0);
    /// @notice Address of the contract for message verification
    address VERIFY_MESSAGE_CONTRACT = address(0);

    /// @notice Signature prefix for mainnet network mode
    string constant MAINNET_PREFIX = "MinaSignatureMainnet";
    /// @notice Signature prefix for testnet network mode
    string constant TESTNET_PREFIX = "CodaSignature*******";

    /// @notice Setting for no computation (Ie no lzMap/lzReduce)
    uint8 constant SETTING_NONE = 3;

    uint32 constant READ_CHANNEL_EID_THRESHOLD = 4294965694;
    uint32 READ_CHANNEL_ID = 4294967295;
    uint32 READ_FROM_ENDPOINT_ID = 30110;
    uint32 READ_TO_ENDPOINT_ID = 30101;

    uint16 BLOCK_CONFIRMATIONS = 3;

    /// @notice Conservative gas limit for transactions (100 Chars/20 Fields)
    /// @dev Decoding gas - 30k/38k
    ModeConfig CONSERVATIVE_CONFIG = ModeConfig({ gasLimit: 120_000, messageSize: 800, fieldsSize: 2000 });

    /// @notice Default gas limit for transactions (250 Chars/50 Fields)
    /// @dev Decoding gas - 32k/55k
    ModeConfig DEFAULT_CONFIG = ModeConfig({ gasLimit: 150_000, messageSize: 1100, fieldsSize: 3800 });

    /// @notice Optimistic gas limit for transactions (500 Chars/100 Fields)
    /// @dev Decoding gas - 37k/82k
    ModeConfig OPTIMISTIC_CONFIG = ModeConfig({ gasLimit: 200_000, messageSize: 1600, fieldsSize: 7000 });

    ChainConfig CHAIN_CONFIG_VF =
        ChainConfig({ confirmations: BLOCK_CONFIRMATIONS, toReadFrom: VERIFY_FIELDS_CONTRACT });
    ChainConfig CHAIN_CONFIG_VM =
        ChainConfig({ confirmations: BLOCK_CONFIRMATIONS, toReadFrom: VERIFY_MESSAGE_CONTRACT });

    /// @notice Mapping of verification field IDs to their compressed data
    mapping(uint256 => VerifyFieldsStateCompressed) vfIdToData;
    /// @notice Mapping of verification message IDs to their compressed data
    mapping(uint256 => VerifyMessageStateCompressed) vmIdToData;

    /// @notice Emitted when an arbitrary message is received.
    ///         All _lzReceive() calls apart from read responses.
    /// @param origin Origin information of the message
    /// @param message The received message data
    event ArbitraryMessageReceived(Origin origin, bytes message);

    /// @notice Constructor for PallasVerificationReceiever
    /// @param _endpoint Address of the LayerZero endpoint
    /// @param _delegate Address of the delegate
    constructor(address _endpoint, address _delegate) OAppRead(_endpoint, _delegate) Ownable(_delegate) {}

    /// @notice Gets quote for transaction with manual parameters
    /// @param verifyType Type of verification
    /// @param id Verification ID
    /// @param calldataSize Size of calldata
    /// @param gasLimit Gas limit for the transaction
    /// @param payInLzToken Whether to pay in LayerZero tokens
    /// @return QuoteResult Result containing gas and fee information
    function quote(
        TYPE verifyType,
        uint256 id,
        uint32 calldataSize,
        uint128 gasLimit,
        bool payInLzToken
    ) public view returns (QuoteResult memory) {
        if (verifyType == TYPE.VERIFY_PLACEHOLDER_DO_NOT_USE) revert();

        bytes memory _options = OptionsBuilder.newOptions();
        _options = OptionsBuilder.addExecutorLzReadOption(_options, gasLimit, calldataSize, 0);
        bytes memory _cmd = getCmd(verifyType, id);
        MessagingFee memory fee = _quote(READ_FROM_ENDPOINT_ID, _cmd, _options, payInLzToken);

        return
            QuoteResult({
                gasLimit: gasLimit,
                calldataSize: calldataSize,
                nativeFee: fee.nativeFee,
                lzTokenFee: fee.lzTokenFee
            });
    }

    /// @notice Gets automatic quote for transaction
    /// @param verifyType Type of verification
    /// @param id Verification ID
    /// @param mode Whether to use optimistic mode
    /// @param payInLzToken Whether to pay in LayerZero tokens
    /// @return QuoteResult Result containing gas and fee information
    function autoQuote(
        TYPE verifyType,
        uint256 id,
        MODE mode,
        bool payInLzToken
    ) public view returns (QuoteResult memory) {
        if (verifyType == TYPE.VERIFY_PLACEHOLDER_DO_NOT_USE) revert();

        uint128 gasLimit;
        uint32 calldataSize;

        if (mode == MODE.CONSERVATIVE) {
            gasLimit = CONSERVATIVE_CONFIG.gasLimit;
            calldataSize = verifyType == TYPE.VERIFY_MESSAGE
                ? CONSERVATIVE_CONFIG.messageSize
                : CONSERVATIVE_CONFIG.fieldsSize;
        } else if (mode == MODE.DEFAULT) {
            gasLimit = DEFAULT_CONFIG.gasLimit;
            calldataSize = verifyType == TYPE.VERIFY_MESSAGE ? DEFAULT_CONFIG.messageSize : DEFAULT_CONFIG.fieldsSize;
        } else {
            gasLimit = OPTIMISTIC_CONFIG.gasLimit;
            calldataSize = verifyType == TYPE.VERIFY_MESSAGE
                ? OPTIMISTIC_CONFIG.messageSize
                : OPTIMISTIC_CONFIG.fieldsSize;
        }

        bytes memory _options = OptionsBuilder.newOptions();
        _options = OptionsBuilder.addExecutorLzReadOption(_options, gasLimit, calldataSize, 0);
        bytes memory _cmd = getCmd(verifyType, id);
        MessagingFee memory fee = _quote(READ_FROM_ENDPOINT_ID, _cmd, _options, payInLzToken);

        return
            QuoteResult({
                gasLimit: gasLimit,
                calldataSize: calldataSize,
                nativeFee: fee.nativeFee,
                lzTokenFee: fee.lzTokenFee
            });
    }

    /// @notice Gets command bytes for verification
    /// @param verifyType Type of verification
    /// @param id Verification ID
    /// @return bytes The command bytes
    function getCmd(TYPE verifyType, uint256 id) public view returns (bytes memory) {
        bytes memory callData;
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);

        if (verifyType == TYPE.VERIFY_MESSAGE) {
            callData = abi.encodeWithSelector(ICORE_MessageVerification.getVMStateBytesCompressed.selector, id);
            readRequests[0] = EVMCallRequestV1({
                appRequestLabel: uint16(1),
                targetEid: READ_FROM_ENDPOINT_ID,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: CHAIN_CONFIG_VF.confirmations,
                to: CHAIN_CONFIG_VF.toReadFrom,
                callData: callData
            });
        } else if (verifyType == TYPE.VERIFY_FIELDS) {
            callData = abi.encodeWithSelector(ICORE_FieldsVerification.getVFStateBytesCompressed.selector, id);
            readRequests[0] = EVMCallRequestV1({
                appRequestLabel: uint16(1),
                targetEid: READ_FROM_ENDPOINT_ID,
                isBlockNum: false,
                blockNumOrTimestamp: uint64(block.timestamp),
                confirmations: CHAIN_CONFIG_VM.confirmations,
                to: CHAIN_CONFIG_VM.toReadFrom,
                callData: callData
            });
        }

        EVMCallComputeV1 memory computeSettings = EVMCallComputeV1({
            computeSetting: SETTING_NONE,
            targetEid: READ_TO_ENDPOINT_ID,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: BLOCK_CONFIRMATIONS,
            to: address(this)
        });

        return ReadCodecV1.encode(0, readRequests, computeSettings);
    }

    /// @notice Reads compressed bytes with manual parameters
    /// @param verifyType Type of verification
    /// @param id Verification ID
    /// @param calldataSize Size of calldata
    /// @param gasLimit Gas limit for the transaction
    /// @param payInLzToken Whether to pay in LayerZero tokens
    /// @return MessagingReceipt Receipt of the message transaction
    function readBytesCompressedManual(
        TYPE verifyType,
        uint256 id,
        uint32 calldataSize,
        uint128 gasLimit,
        bool payInLzToken
    ) external payable returns (MessagingReceipt memory) {
        if (verifyType == TYPE.VERIFY_PLACEHOLDER_DO_NOT_USE) revert();

        QuoteResult memory result = quote(verifyType, id, calldataSize, gasLimit, payInLzToken);

        if (msg.value < result.nativeFee) {
            revert InsufficientFee(result.nativeFee, msg.value);
        }

        bytes memory _cmd = getCmd(verifyType, id);
        bytes memory _options = OptionsBuilder.newOptions();
        _options = OptionsBuilder.addExecutorLzReadOption(_options, gasLimit, calldataSize, 0);

        return _lzSend(READ_CHANNEL_ID, _cmd, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /// @notice Reads compressed bytes with automatic parameters
    /// @param verifyType Type of verification
    /// @param id Verification ID
    /// @param mode Whether to use conservative/default/optimistic mode
    /// @param payInLzToken Whether to pay in LayerZero tokens
    /// @return MessagingReceipt Receipt of the message transaction
    function readBytesCompressedAuto(
        TYPE verifyType,
        uint256 id,
        MODE mode,
        bool payInLzToken
    ) external payable returns (MessagingReceipt memory) {
        if (verifyType == TYPE.VERIFY_PLACEHOLDER_DO_NOT_USE) revert();

        QuoteResult memory result = autoQuote(verifyType, id, mode, payInLzToken);

        if (msg.value < result.nativeFee) {
            revert InsufficientFee(result.nativeFee, msg.value);
        }

        bytes memory _cmd = getCmd(verifyType, id);
        bytes memory _options = OptionsBuilder.newOptions();
        _options = OptionsBuilder.addExecutorLzReadOption(_options, result.gasLimit, result.calldataSize, 0);

        return _lzSend(READ_CHANNEL_ID, _cmd, _options, MessagingFee(msg.value, 0), payable(msg.sender));
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
        Origin calldata _origin,
        bytes32 /* _guid */,
        bytes calldata _message,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) internal virtual {
        TYPE verifyType = TYPE(uint8(_message[0]));

        if (verifyType == TYPE.VERIFY_FIELDS) {
            (uint256 id, VerifyFieldsStateCompressed memory state) = unpackVerifyFieldsState(_message);
            vfIdToData[id] = state;
        } else if (verifyType == TYPE.VERIFY_MESSAGE) {
            (uint256 id, VerifyMessageStateCompressed memory state) = unpackVerifyMessageState(_message);
            vmIdToData[id] = state;
        } else {
            emit ArbitraryMessageReceived(_origin, _message);
        }
    }

    /// @notice Unpacks verify fields state from bytes
    /// @param data The encoded fields state data
    /// @return id The fields ID
    /// @return state The unpacked verify fields state
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
            x := calldataload(add(data.offset, 35))
            y := calldataload(add(data.offset, 67))
            r := calldataload(add(data.offset, 99))
            s := calldataload(add(data.offset, 131))
            messageHash := calldataload(add(data.offset, 163))
        }

        state.publicKey.x = x;
        state.publicKey.y = y;
        state.signature.r = r;
        state.signature.s = s;
        state.messageHash = messageHash;
        state.prefix = "CodaSignature*******";

        state.fields = abi.decode(data[195:], (uint256[]));
        return (state.vfId, state);
    }

    /// @notice Unpacks verify message state from bytes
    /// @param data The encoded message state data
    /// @return id The message ID
    /// @return state The unpacked verify message state
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
            x := calldataload(add(data.offset, 35))
            y := calldataload(add(data.offset, 67))
            r := calldataload(add(data.offset, 99))
            s := calldataload(add(data.offset, 131))
            messageHash := calldataload(add(data.offset, 163))
        }

        state.publicKey.x = x;
        state.publicKey.y = y;
        state.signature.r = r;
        state.signature.s = s;
        state.messageHash = messageHash;
        state.prefix = state.mainnet ? "MinaSignatureMainnet" : "CodaSignature*******";
        state.message = abi.decode(data[195:], (string));
        return (state.vmId, state);
    }

    /// ===========================================================================
    /// ADMIN STORAGE UPDATE FUNCTIONS ============================================
    /// ===========================================================================

    function updateVerifyFieldsContract(address addr) external onlyOwner {
        require(addr != address(0));
        VERIFY_FIELDS_CONTRACT = addr;
    }

    function updateVerifyMessageContract(address addr) external onlyOwner {
        require(addr != address(0));
        VERIFY_MESSAGE_CONTRACT = addr;
    }

    function updateBlockConfirmations(uint16 confirmations) external onlyOwner {
        require(confirmations != 0);
        BLOCK_CONFIRMATIONS = confirmations;
    }

    function updateReadChannelId(uint32 id) external onlyOwner {
        READ_CHANNEL_ID = id;
    }

    function updateReadFromEndpointId(uint32 id) external onlyOwner {
        READ_FROM_ENDPOINT_ID = id;
    }

    function updateReadToEndpointId(uint32 id) external onlyOwner {
        READ_TO_ENDPOINT_ID = id;
    }

    function updateConservativeModeParams(
        uint128 gasLimit,
        uint32 messageSizeBytes,
        uint32 fieldsSizeBytes
    ) external onlyOwner {
        CONSERVATIVE_CONFIG.gasLimit = gasLimit;
        CONSERVATIVE_CONFIG.messageSize = messageSizeBytes;
        CONSERVATIVE_CONFIG.fieldsSize = fieldsSizeBytes;
    }

    function updateDefaultModeParams(
        uint128 gasLimit,
        uint32 messageSizeBytes,
        uint32 fieldsSizeBytes
    ) external onlyOwner {
        DEFAULT_CONFIG.gasLimit = gasLimit;
        DEFAULT_CONFIG.messageSize = messageSizeBytes;
        DEFAULT_CONFIG.fieldsSize = fieldsSizeBytes;
    }

    function updateOptimisticModeParams(
        uint128 gasLimit,
        uint32 messageSizeBytes,
        uint32 fieldsSizeBytes
    ) external onlyOwner {
        OPTIMISTIC_CONFIG.gasLimit = gasLimit;
        OPTIMISTIC_CONFIG.messageSize = messageSizeBytes;
        OPTIMISTIC_CONFIG.fieldsSize = fieldsSizeBytes;
    }
}
