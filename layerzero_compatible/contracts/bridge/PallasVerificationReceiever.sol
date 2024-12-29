// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SetConfigParam } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import { OAppReceiver, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

struct OptimizedPoint {
    bytes32 x;
    bytes32 y;
}

struct OptimizedSignature {
    bytes32 r;
    bytes32 s;
}

struct BatchedVerifications {
    bytes32[] fieldsData;
    bytes32[] messageHashes;
    OptimizedSignature[] signatures;
    OptimizedPoint[] keys;
    bool[] isValid;
}

struct OptimizedFieldsVerification {
    uint256 vfId;
    bool isValid;
    bytes32[] fields;
    OptimizedSignature signature;
    OptimizedPoint publicKey;
}

struct OptimizedMessageVerification {
    uint256 vmId;
    bool isValid;
    bytes32 messageHash;
    OptimizedSignature signature;
    OptimizedPoint publicKey;
}

struct OptimizedOriginalMessageVerification {
    uint256 vmId;
    bool isValid;
    OptimizedSignature signature;
    OptimizedPoint publicKey;
    string message;
}

contract PallasVerificationReceiever is OAppReceiver {
    mapping(uint256 => OptimizedFieldsVerification) vfIdToData;
    mapping(uint256 => OptimizedMessageVerification) vmIdToCompressedData;
    mapping(uint256 => OptimizedOriginalMessageVerification) vmIdToData;

    constructor(address _endpoint, address _delegate) Ownable(msg.sender) OAppCore(_endpoint, _delegate) {}

    event FieldsVerificationReceived(
        uint256 indexed vfId,
        bool indexed isValid,
        bytes32[] fields,
        OptimizedSignature signature,
        OptimizedPoint key
    );

    event MessageVerificationReceived(
        uint256 indexed vmId,
        bool indexed isValid,
        bytes32 messageHash,
        OptimizedSignature signature,
        OptimizedPoint key
    );

    event OriginalMessageVerificationReceived(
        uint256 indexed vmId,
        bool indexed isValid,
        string message,
        OptimizedSignature signature,
        OptimizedPoint key
    );

    // ChainId       : 1
    // EndpointId    : 30101
    // EndpointV2    : 0x1a44076050125825900e736c501f859c50fE728c
    // SendUln302    : 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
    // ReceiveUln302 : 0xc02Ab410f0734EFa3F14628780e6e695156024C2
    // LZ Executor   : 0x173272739Bd7Aa6e4e214714048a9fE699453059
    // LZ Dead DVN   : 0x747C741496a507E4B404b50463e691A8d692f6Ac
    //  const receiveTx = await endpointContract.setReceiveLibrary(
    //   YOUR_OAPP_ADDRESS,
    //   remoteEid,
    //   YOUR_RECEIVE_LIB_ADDRESS,
    // );
    function _lzReceive(Origin calldata, bytes32, bytes calldata _payload, address, bytes calldata) internal override {
        uint8 typeId = uint8(_payload[0]);

        if (typeId == 1) {
            OptimizedFieldsVerification memory verification = decodeSingleFieldsVerification(_payload);
            vfIdToData[verification.vfId] = verification;
            emit FieldsVerificationReceived(
                verification.vfId,
                verification.isValid,
                verification.fields,
                verification.signature,
                verification.publicKey
            );
        } else if (typeId == 2) {
            OptimizedMessageVerification memory verification = decodeSingleMessageVerification(_payload);
            vmIdToCompressedData[verification.vmId] = verification;
            emit MessageVerificationReceived(
                verification.vmId,
                verification.isValid,
                verification.messageHash,
                verification.signature,
                verification.publicKey
            );
        } else if (typeId == 3) {
            OptimizedOriginalMessageVerification memory verification = decodeSingleOriginalMessageVerification(
                _payload
            );
            vmIdToData[verification.vmId] = verification;
            emit OriginalMessageVerificationReceived(
                verification.vmId,
                verification.isValid,
                verification.message,
                verification.signature,
                verification.publicKey
            );
        } else {
            revert("Invalid message type");
        }
    }

    function decodeSingleFieldsVerification(
        bytes memory _payload
    ) internal pure returns (OptimizedFieldsVerification memory) {
        require(_payload[0] == 0x01, "Invalid type for single fields");

        OptimizedFieldsVerification memory verification;
        uint16 fieldsLength;

        assembly {
            let pointer := add(_payload, 1)

            // Load vfId directly
            mstore(add(verification, 0x20), mload(add(pointer, 0x00)))

            // Load isValid
            switch mload(add(pointer, 32))
            case 0 {
                mstore(add(verification, 0x40), 0)
            }
            default {
                mstore(add(verification, 0x40), 1)
            }

            pointer := add(pointer, 33) // move past vfId and isValid

            // Get fields length
            fieldsLength := mload(pointer)
            pointer := add(pointer, 32)

            // Setup fields array
            let fieldsPtr := add(verification, 0x60)
            let newFieldsArr := mload(0x40) // get free memory pointer
            mstore(0x40, add(add(newFieldsArr, 0x20), mul(fieldsLength, 0x20))) // update free memory pointer
            mstore(newFieldsArr, fieldsLength) // store length
            mstore(fieldsPtr, newFieldsArr) // store array pointer

            // Copy fields
            let destPtr := add(newFieldsArr, 0x20)
            for {
                let i := 0
            } lt(i, fieldsLength) {
                i := add(i, 1)
            } {
                mstore(add(destPtr, mul(i, 0x20)), mload(pointer))
                pointer := add(pointer, 0x20)
            }

            // Load signature
            let sig := add(verification, 0x80)
            let sigPtr := mload(0x40)
            mstore(0x40, add(sigPtr, 0x40))
            mstore(sig, sigPtr)

            mstore(sigPtr, mload(pointer)) // r
            pointer := add(pointer, 32)
            mstore(add(sigPtr, 32), mload(pointer)) // s
            pointer := add(pointer, 32)

            // Load public key
            let pk := add(verification, 0xA0)
            let pkPtr := mload(0x40)
            mstore(0x40, add(pkPtr, 0x40))
            mstore(pk, pkPtr)

            mstore(pkPtr, mload(pointer)) // x
            pointer := add(pointer, 32)
            mstore(add(pkPtr, 32), mload(pointer)) // y
        }

        return verification;
    }

    // Decoder for single message verification
    function decodeSingleMessageVerification(
        bytes memory _payload
    ) internal pure returns (OptimizedMessageVerification memory) {
        require(_payload[0] == 0x02, "Invalid type for single message");

        OptimizedMessageVerification memory verification;

        assembly {
            let pointer := add(_payload, 1)

            // Load vmId directly
            mstore(add(verification, 0x20), mload(add(pointer, 0x00)))

            // Load isValid
            switch mload(add(pointer, 32))
            case 0 {
                mstore(add(verification, 0x40), 0)
            }
            default {
                mstore(add(verification, 0x40), 1)
            }

            pointer := add(pointer, 33) // move past vmId and isValid

            // Load messageHash
            mstore(add(verification, 0x60), mload(pointer))
            pointer := add(pointer, 32)

            // Load signature
            let sig := add(verification, 0x80)
            let sigPtr := mload(0x40)
            mstore(0x40, add(sigPtr, 0x40))
            mstore(sig, sigPtr)

            mstore(sigPtr, mload(pointer))
            pointer := add(pointer, 32)
            mstore(add(sigPtr, 32), mload(pointer))
            pointer := add(pointer, 32)

            // Load public key
            let pk := add(verification, 0xA0)
            let pkPtr := mload(0x40)
            mstore(0x40, add(pkPtr, 0x40))
            mstore(pk, pkPtr)

            mstore(pkPtr, mload(pointer))
            pointer := add(pointer, 32)
            mstore(add(pkPtr, 32), mload(pointer))
        }

        return verification;
    }

    // Add these new decoder functions
    function decodeSingleOriginalMessageVerification(
        bytes memory _payload
    ) internal pure returns (OptimizedOriginalMessageVerification memory) {
        require(_payload[0] == 0x03, "Invalid type for original message");

        OptimizedOriginalMessageVerification memory verification;
        uint256 messageLength;

        assembly {
            let pointer := add(_payload, 1)

            // Load vmId directly
            mstore(add(verification, 0x20), mload(add(pointer, 0x00)))

            // Load isValid
            switch mload(add(pointer, 32))
            case 0 {
                mstore(add(verification, 0x40), 0)
            }
            default {
                mstore(add(verification, 0x40), 1)
            }

            pointer := add(pointer, 33) // move past vmId and isValid

            // Get message length
            messageLength := mload(pointer)
            pointer := add(pointer, 32)
        }

        // Handle message separately from assembly
        bytes memory messageBytes = new bytes(messageLength);
        assembly {
            let msgPtr := add(messageBytes, 32)
            let payloadPtr := add(_payload, 66) // type(1) + vmId(32) + isValid(1) + length(32)

            // Copy message bytes
            for {
                let i := 0
            } lt(i, messageLength) {
                i := add(i, 32)
            } {
                mstore(add(msgPtr, i), mload(add(payloadPtr, i)))
            }
            mstore(messageBytes, messageLength)
        }
        verification.message = string(messageBytes);

        // Continue with signature and public key
        assembly {
            let pointer := add(add(_payload, 66), messageLength) // Start after message

            // Load signature
            let sig := add(verification, 0x60)
            let sigPtr := mload(0x40)
            mstore(0x40, add(sigPtr, 0x40))
            mstore(sig, sigPtr)

            mstore(sigPtr, mload(pointer))
            pointer := add(pointer, 32)
            mstore(add(sigPtr, 32), mload(pointer))
            pointer := add(pointer, 32)

            // Load public key
            let pk := add(verification, 0x80)
            let pkPtr := mload(0x40)
            mstore(0x40, add(pkPtr, 0x40))
            mstore(pk, pkPtr)

            mstore(pkPtr, mload(pointer))
            pointer := add(pointer, 32)
            mstore(add(pkPtr, 32), mload(pointer))
        }

        return verification;
    }

    function setConfig(uint32 _eid, uint32 _configType, bytes calldata _config) external onlyOwner {
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({ eid: _eid, configType: _configType, config: _config });

        endpoint.setConfig(
            address(this),
            address(0), // since we're not configuring a specific library
            params
        );
    }

    function oAppVersion() public pure override returns (uint64 senderVersion, uint64 receiverVersion) {
        return (1, 1); // You can adjust these version numbers as needed
    }
}