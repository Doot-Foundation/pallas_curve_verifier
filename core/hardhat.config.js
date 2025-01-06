require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();
// require("hardhat-gas-reporter");
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
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    hardhat: {},
    arbitrum_sepolia: {
      chainId: 421614,
      url: process.env.ARBITRUM_SEPOLIA_RPC
        ? process.env.ARBITRUM_SEPOLIA_RPC
        : "https://sepolia-rollup.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY],
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY,
        },
      },
    },
    arbitrum: {
      chainId: 42161,
      url: process.env.ARBITRUM_RPC
        ? process.env.ARBITRUM_RPC
        : "https://arb1.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY],
      verify: {
        etherscan: {
          apiKey: process.env.ARBISCAN_API_KEY,
        },
      },
    },
  },
  etherscan: {
    apiKey: {
      arbitrum_sepolia: process.env.ARBISCAN_API_KEY,
      arbitrum: process.env.ARBISCAN_API_KEY,
    },
    customChains: [
      {
        network: "arbitrum_sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io",
        },
      },
      {
        network: "arbitrum",
        chainId: 42161,
        urls: {
          apiURL: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io/",
        },
      },
    ],
  },
  mocha: {
    timeout: 100000,
  },
  sourcify: {
    enabled: true,
  },
};
