// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
struct Point {
    uint256 x;
    uint256 y;
}

struct PointCompressed {
    uint256 x;
    bool isOdd;
}

struct Signature {
    uint256 r;
    uint256 s;
}

struct ProjectivePoint {
    uint256 x;
    uint256 y;
    uint256 z;
}

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

struct FieldsVerification {
    bool isValid;
    uint256[] fields;
    Signature signature;
    Point publicKey;
}

struct MessageVerification {
    bool isValid;
    string message;
    Signature signature;
    Point publicKey;
}

struct OptimizedFieldsVerification {
    bool isValid;
    bytes32[] fields;
    OptimizedSignature signature;
    OptimizedPoint publicKey;
}

struct OptimizedMessageVerification {
    bool isValid;
    bytes32 messageHash;
    OptimizedSignature signature;
    OptimizedPoint publicKey;
}
struct OptimizedOriginalMessageVerification {
    bool isValid;
    OptimizedSignature signature;
    OptimizedPoint publicKey;
    string message;
}

contract EthereumReceiver {
    address public immutable trustedRemote;
    uint16 public immutable srcChainId;
    address public immutable lzEndpoint;

    constructor(
        address _trustedRemote,
        uint16 _srcChainId,
        address _lzEndpoint
    ) {
        trustedRemote = _trustedRemote;
        srcChainId = _srcChainId;
        lzEndpoint = _lzEndpoint;
    }

    modifier onlyLzEndpoint() {
        require(msg.sender == lzEndpoint, "Only LayerZero endpoint can call");
        _;
    }

    event OriginalMessageVerificationReceived(
        bool indexed isValid,
        string message,
        OptimizedSignature signature,
        OptimizedPoint key
    );

    event FieldsVerificationReceived(
        bool indexed isValid,
        bytes32[] fields,
        OptimizedSignature signature,
        OptimizedPoint key
    );

    event MessageVerificationReceived(
        bool indexed isValid,
        bytes32 messageHash,
        OptimizedSignature signature,
        OptimizedPoint key
    );

    // event BatchReceived(uint8 batchType, uint16 verificationCount);

    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) external onlyLzEndpoint {
        // Validate source chain and address
        require(_srcChainId == srcChainId, "Invalid source chain");
        require(
            _srcAddress.length == 20 &&
                address(bytes20(_srcAddress)) == trustedRemote,
            "Invalid source address"
        );

        uint8 typeId = uint8(_payload[0]);

        if (typeId == 1) {
            OptimizedFieldsVerification
                memory verification = decodeSingleFieldsVerification(_payload);
            emit FieldsVerificationReceived(
                verification.isValid,
                verification.fields,
                verification.signature,
                verification.publicKey
            );
        } else if (typeId == 2) {
            OptimizedMessageVerification
                memory verification = decodeSingleMessageVerification(_payload);
            emit MessageVerificationReceived(
                verification.isValid,
                verification.messageHash,
                verification.signature,
                verification.publicKey
            );
        } else if (typeId == 3) {
            OptimizedOriginalMessageVerification
                memory verification = decodeSingleOriginalMessageVerification(
                    _payload
                );
            emit OriginalMessageVerificationReceived(
                verification.isValid,
                verification.message,
                verification.signature,
                verification.publicKey
            );
        }
        // else if (typeId == 4) {
        //     decodeBatchedFieldsVerifications(_payload);
        // } else if (typeId == 5) {
        //     decodeBatchedMessageVerifications(_payload);
        // } else if (typeId == 6) {
        //     decodeBatchedOriginalMessageVerifications(_payload);
        // }
    }

    function decodeSingleFieldsVerification(
        bytes memory _payload
    ) internal pure returns (OptimizedFieldsVerification memory) {
        require(_payload[0] == 0x01, "Invalid type for single fields");

        OptimizedFieldsVerification memory verification;

        uint256 pointer;
        assembly {
            pointer := add(_payload, 33) // skip type (1) + isValid (32)
        }

        // Extract isValid (1 byte after type)
        verification.isValid = _payload[1] != 0;

        // Extract fields length
        uint16 fieldsLength;
        assembly {
            fieldsLength := mload(pointer)
            pointer := add(pointer, 32)
        }

        // Extract fields
        verification.fields = new bytes32[](fieldsLength);
        for (uint16 i = 0; i < fieldsLength; i++) {
            assembly {
                mstore(
                    add(add(mload(add(verification, 0x40)), 32), mul(i, 32)),
                    mload(pointer)
                )
                pointer := add(pointer, 32)
            }
        }

        // Extract signature and public key
        assembly {
            let sig := add(verification, 0x60) // offset to signature
            let pk := add(verification, 0xA0) // offset to public key

            // Load signature
            let sigPtr := mload(sig)
            mstore(sigPtr, mload(pointer)) // r
            pointer := add(pointer, 32)
            mstore(add(sigPtr, 32), mload(pointer)) // s
            pointer := add(pointer, 32)

            // Load public key
            let pkPtr := mload(pk)
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
        verification.isValid = _payload[1] != 0;

        assembly {
            let pointer := add(_payload, 34) // skip type (1) + isValid (1) + align to 32

            // Load messageHash
            mstore(add(verification, 0x40), mload(pointer))
            pointer := add(pointer, 32)

            // Load signature
            let sig := add(verification, 0x60) // offset to signature
            let sigPtr := mload(sig)
            mstore(sigPtr, mload(pointer)) // r
            pointer := add(pointer, 32)
            mstore(add(sigPtr, 32), mload(pointer)) // s
            pointer := add(pointer, 32)

            // Load public key
            let pk := add(verification, 0xA0) // offset to public key
            let pkPtr := mload(pk)
            mstore(pkPtr, mload(pointer)) // x
            pointer := add(pointer, 32)
            mstore(add(pkPtr, 32), mload(pointer)) // y
        }

        return verification;
    }

    // Add these new decoder functions
    function decodeSingleOriginalMessageVerification(
        bytes memory _payload
    ) internal pure returns (OptimizedOriginalMessageVerification memory) {
        require(
            _payload[0] == 0x05,
            "Invalid type for single original message"
        );

        OptimizedOriginalMessageVerification memory verification;
        verification.isValid = _payload[1] != 0;

        uint256 pointer;
        uint256 messageLength;
        assembly {
            pointer := add(_payload, 34) // skip type (1) + isValid (1) + align to 32
            messageLength := mload(pointer)
            pointer := add(pointer, 32)
        }

        // Extract message
        bytes memory messageBytes = new bytes(messageLength);
        assembly {
            let msgPtr := add(messageBytes, 32)
            let payloadPtr := pointer
            for {
                let i := 0
            } lt(i, messageLength) {
                i := add(i, 32)
            } {
                mstore(add(msgPtr, i), mload(add(payloadPtr, i)))
            }
            mstore(messageBytes, messageLength) // Set length of bytes array
        }
        verification.message = string(messageBytes);

        // Update pointer to skip the message bytes
        assembly {
            pointer := add(pointer, messageLength)

            // Load signature
            let sig := add(verification, 0x40) // offset to signature
            let sigPtr := mload(sig)
            mstore(sigPtr, mload(pointer)) // r
            pointer := add(pointer, 32)
            mstore(add(sigPtr, 32), mload(pointer)) // s
            pointer := add(pointer, 32)

            // Load public key
            let pk := add(verification, 0x60) // offset to public key
            let pkPtr := mload(pk)
            mstore(pkPtr, mload(pointer)) // x
            pointer := add(pointer, 32)
            mstore(add(pkPtr, 32), mload(pointer)) // y
        }

        return verification;
    }

    // function decodeBatchedFieldsVerifications(bytes memory _payload) internal {
    //     require(_payload[0] == 0x03, "Invalid type for batched fields");

    //     // Extract validity packed (32 bytes after type)
    //     uint256 validityPacked;
    //     assembly {
    //         validityPacked := mload(add(_payload, 1))
    //     }

    //     uint256 pointer;
    //     assembly {
    //         pointer := add(_payload, 33) // skip type + validityPacked
    //     }

    //     uint256 i = 0;
    //     while (pointer < _payload.length) {
    //         OptimizedFieldsVerification memory verification;
    //         verification.isValid = (validityPacked & (1 << i)) != 0;

    //         // Extract fields length
    //         uint16 fieldsLength;
    //         assembly {
    //             fieldsLength := mload(pointer)
    //             pointer := add(pointer, 32)
    //         }

    //         // Extract fields
    //         verification.fields = new bytes32[](fieldsLength);
    //         for (uint16 j = 0; j < fieldsLength; j++) {
    //             assembly {
    //                 mstore(
    //                     add(
    //                         add(mload(add(verification, 0x40)), 32),
    //                         mul(j, 32)
    //                     ),
    //                     mload(pointer)
    //                 )
    //                 pointer := add(pointer, 32)
    //             }
    //         }

    //         // Extract signature and public key
    //         assembly {
    //             let sig := add(verification, 0x60) // offset to signature
    //             let pk := add(verification, 0xA0) // offset to public key

    //             // Load signature
    //             let sigPtr := mload(sig)
    //             mstore(sigPtr, mload(pointer)) // r
    //             pointer := add(pointer, 32)
    //             mstore(add(sigPtr, 32), mload(pointer)) // s
    //             pointer := add(pointer, 32)

    //             // Load public key
    //             let pkPtr := mload(pk)
    //             mstore(pkPtr, mload(pointer)) // x
    //             pointer := add(pointer, 32)
    //             mstore(add(pkPtr, 32), mload(pointer)) // y
    //             pointer := add(pointer, 32)
    //         }

    //         emit FieldsVerificationReceived(
    //             verification.isValid,
    //             verification.fields,
    //             verification.signature,
    //             verification.publicKey
    //         );

    //         i++;
    //     }

    //     emit BatchReceived(3, uint16(i));
    // }

    // function decodeBatchedMessageVerifications(bytes memory _payload) internal {
    //     require(_payload[0] == 0x04, "Invalid type for batched messages");

    //     uint256 validityPacked;
    //     assembly {
    //         validityPacked := mload(add(_payload, 1))
    //     }

    //     uint256 pointer;
    //     assembly {
    //         pointer := add(_payload, 33) // skip type + validityPacked
    //     }

    //     uint256 i = 0;
    //     while (pointer < _payload.length) {
    //         OptimizedMessageVerification memory verification;
    //         verification.isValid = (validityPacked & (1 << i)) != 0;

    //         assembly {
    //             // Load messageHash
    //             mstore(add(verification, 0x40), mload(pointer))
    //             pointer := add(pointer, 32)

    //             let sig := add(verification, 0x60) // offset to signature
    //             let pk := add(verification, 0xA0) // offset to public key

    //             // Load signature
    //             let sigPtr := mload(sig)
    //             mstore(sigPtr, mload(pointer)) // r
    //             pointer := add(pointer, 32)
    //             mstore(add(sigPtr, 32), mload(pointer)) // s
    //             pointer := add(pointer, 32)

    //             // Load public key
    //             let pkPtr := mload(pk)
    //             mstore(pkPtr, mload(pointer)) // x
    //             pointer := add(pointer, 32)
    //             mstore(add(pkPtr, 32), mload(pointer)) // y
    //             pointer := add(pointer, 32)
    //         }

    //         emit MessageVerificationReceived(
    //             verification.isValid,
    //             verification.messageHash,
    //             verification.signature,
    //             verification.publicKey
    //         );

    //         i++;
    //     }

    //     emit BatchReceived(4, uint16(i));
    // }

    // function decodeBatchedOriginalMessageVerifications(
    //     bytes memory _payload
    // ) internal {
    //     require(
    //         _payload[0] == 0x06,
    //         "Invalid type for batched original messages"
    //     );

    //     uint256 validityPacked;
    //     assembly {
    //         validityPacked := mload(add(_payload, 1))
    //     }

    //     uint256 pointer;
    //     assembly {
    //         pointer := add(_payload, 33) // skip type + validityPacked
    //     }

    //     uint256 i = 0;
    //     while (pointer < _payload.length) {
    //         OptimizedOriginalMessageVerification memory verification;
    //         verification.isValid = (validityPacked & (1 << i)) != 0;

    //         // Extract message length and message
    //         uint256 messageLength;
    //         assembly {
    //             messageLength := mload(pointer)
    //             pointer := add(pointer, 32)
    //         }

    //         // Extract message
    //         bytes memory messageBytes = new bytes(messageLength);
    //         assembly {
    //             let msgPtr := add(messageBytes, 32)
    //             let payloadPtr := pointer
    //             for {
    //                 let j := 0
    //             } lt(j, messageLength) {
    //                 j := add(j, 32)
    //             } {
    //                 mstore(add(msgPtr, j), mload(add(payloadPtr, j)))
    //             }
    //             mstore(messageBytes, messageLength) // Set length of bytes array
    //         }
    //         verification.message = string(messageBytes);

    //         assembly {
    //             pointer := add(pointer, messageLength)

    //             // Load signature
    //             let sig := add(verification, 0x40) // offset to signature
    //             let sigPtr := mload(sig)
    //             mstore(sigPtr, mload(pointer)) // r
    //             pointer := add(pointer, 32)
    //             mstore(add(sigPtr, 32), mload(pointer)) // s
    //             pointer := add(pointer, 32)

    //             // Load public key
    //             let pk := add(verification, 0x60) // offset to public key
    //             let pkPtr := mload(pk)
    //             mstore(pkPtr, mload(pointer)) // x
    //             pointer := add(pointer, 32)
    //             mstore(add(pkPtr, 32), mload(pointer)) // y
    //             pointer := add(pointer, 32)
    //         }

    //         emit OriginalMessageVerificationReceived(
    //             verification.isValid,
    //             verification.message,
    //             verification.signature,
    //             verification.publicKey
    //         );

    //         i++;
    //     }

    //     emit BatchReceived(6, uint16(i));
    // }

    // Add your custom verification logic functions here
    function verifyFields(
        OptimizedFieldsVerification memory verification
    ) internal pure returns (bool) {
        // Implement your verification logic
        return true;
    }

    function verifyMessage(
        OptimizedMessageVerification memory verification
    ) internal pure returns (bool) {
        // Implement your verification logic
        return true;
    }
}
