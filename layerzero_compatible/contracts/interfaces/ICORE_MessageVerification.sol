//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "../PallasTypes.sol";

interface ICORE_MessageVerification {
    function getVMStateBytesCompressed(uint256 vmId) external view returns (bytes memory);
}
