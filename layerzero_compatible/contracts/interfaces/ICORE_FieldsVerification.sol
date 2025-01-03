//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "../PallasTypes.sol";

interface ICORE_FieldsVerification {
    function getVFStateBytesCompressed(uint256 vfId) external view returns (bytes memory);
}
