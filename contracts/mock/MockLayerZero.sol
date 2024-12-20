// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILzReceiver {
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) external;
}

contract MockLZEndpoint {
    uint16 public chainId;

    mapping(address => address) public destinations; // local address => remote address
    mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32)))
        public failedMessages;

    event PayloadStored(address dstAddress, bytes payload);
    event PayloadCleared();

    constructor(uint16 _chainId) {
        chainId = _chainId;
    }

    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable {
        address dstAddress = address(bytes20(_destination));

        // Mock the cross-chain message by directly calling the destination
        bytes memory path = abi.encodePacked(msg.sender, dstAddress);

        // Get the remote endpoint for the destination chain
        address dstEndpoint = destinations[dstAddress];
        require(dstEndpoint != address(0), "Destination not registered");

        // Forward the message to the destination
        bytes memory srcAddress = abi.encodePacked(msg.sender);

        // Call the destination contract's lzReceive
        try
            ILzReceiver(dstAddress).lzReceive(chainId, srcAddress, 0, _payload)
        {} catch (bytes memory) {
            failedMessages[_dstChainId][path][0] = keccak256(_payload);
            emit PayloadStored(dstAddress, _payload);
        }
    }

    function registerDestination(address _local, address _remote) external {
        destinations[_local] = _remote;
    }
}
