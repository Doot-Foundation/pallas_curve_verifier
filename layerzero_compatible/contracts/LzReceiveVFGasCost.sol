///SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

/// @title Point Structure
/// @notice Represents a point on an elliptic curve with x and y coordinates
/// @dev Used for public key and signature operations
struct Point {
    uint256 x;
    uint256 y;
}

/// @title Compressed Point Structure
/// @notice Represents a compressed form of an elliptic curve point
/// @dev Uses x-coordinate and a boolean flag instead of full coordinates
struct PointCompressed {
    uint256 x;
    bool isOdd;
}

/// @title Digital Signature Structure
/// @notice Represents a digital signature with its components
/// @dev Used for cryptographic signature verification
struct Signature {
    uint256 r;
    uint256 s;
}

/// @title Projective Point Structure
/// @notice Represents a point in projective coordinates
/// @dev Used for efficient elliptic curve operations
struct ProjectivePoint {
    uint256 x;
    uint256 y;
    uint256 z;
}

enum TYPE {
    VERIFY_PLACEHOLDER_DO_NOT_USE,
    VERIFY_MESSAGE,
    VERIFY_FIELDS
}

/// @notice Type of automatic modes. Helps decide ModeConfig.
enum MODE {
    CONSERVATIVE,
    DEFAULT,
    OPTIMISTIC
}

struct VerifyFieldsStateCompressed {
    /// @notice Indicates the type. 1 for Message, 2 for Fields. Helpful when reading
    uint8 verifyType;
    /// @notice The unique id
    uint256 vfId;
    /// @notice Network flag - true for mainnet, false for testnet
    bool mainnet;
    /// @notice Final verification result
    bool isValid;
    /// @notice The public key point (x,y) being verified against
    Point publicKey;
    /// @notice The signature containing r (x-coordinate) and s (scalar)
    Signature signature;
    /// @notice Hash of the fields array with prefix ('e' value)
    uint256 messageHash;
    /// @notice Network-specific prefix for message hashing
    string prefix;
    /// @notice Array of field elements to verify
    uint256[] fields;
}

contract LzReceiveVFGasCost {
    mapping(uint256 => VerifyFieldsStateCompressed) public vfIdToData;

    function get(uint256 id) external view returns (VerifyFieldsStateCompressed memory) {
        return vfIdToData[id];
    }

    function lzReceive(bytes calldata _message) external {
        _lzReceive(_message);
    }

    function _lzReceive(bytes calldata _message) internal {
        bytes memory decoded = abi.decode(_message, (bytes));
        this._calldataReadLzReceive(decoded);
    }

    function _calldataReadLzReceive(bytes calldata _message) external {
        require(msg.sender == address(this), "Reserved for self.");
        _readLzReceive(_message);
    }

    function _readLzReceive(bytes calldata _message) internal virtual {
        TYPE verifyType = TYPE(uint8(_message[0]));

        if (verifyType == TYPE.VERIFY_FIELDS) {
            (uint256 id, VerifyFieldsStateCompressed memory state) = _unpackVerifyFieldsState(_message);
            vfIdToData[id] = state;
        }
    }

    /// @notice Unpacks verify fields state from bytes
    /// @param data The encoded fields state data
    /// @return id The fields ID
    /// @return state The unpacked verify fields state
    function _unpackVerifyFieldsState(
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
}
