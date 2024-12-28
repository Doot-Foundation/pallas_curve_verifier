require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000,
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
          },
        },
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      // allowUnlimitedContractSize: true,
      // blockGasLimit: 100000000000, // Practically unlimited
      // gas: 100000000000,
    },
    l1: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    l2: {
      url: "http://127.0.0.1:8546",
      chainId: 31338,
    },
  },
  mocha: {
    timeout: 100000,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};
