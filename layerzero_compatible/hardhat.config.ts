// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import 'dotenv/config'
import '@nomicfoundation/hardhat-verify'
import 'hardhat-deploy'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

const ARBITRUM_SEPOLIA_RPC = process.env.ARB_SEPOLIA_RPC
const ARBITRUM_RPC = process.env.ARB_RPC
const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY

const ETHEREUM_SEPOLIA_RPC = process.env.ETH_SEPOLIA_RPC
const ETHEREUM_RPC = process.env.ETH_RPC
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
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
        ],
    },
    networks: {
        arbitrum_sepolia: {
            chainId: 421614,
            url: ARBITRUM_SEPOLIA_RPC ? ARBITRUM_SEPOLIA_RPC : 'https://sepolia-rollup.arbitrum.io/rpc',
            accounts: [PRIVATE_KEY ? PRIVATE_KEY : ''],
            verify: {
                etherscan: {
                    apiKey: ARBISCAN_API_KEY,
                },
            },
        },
        arbitrum: {
            chainId: 42161,
            url: ARBITRUM_RPC ? ARBITRUM_RPC : 'https://arb1.arbitrum.io/rpc',
            accounts: [PRIVATE_KEY ? PRIVATE_KEY : ''],
            verify: {
                etherscan: {
                    apiKey: ARBISCAN_API_KEY,
                },
            },
        },
        ethereum_sepolia: {
            chainId: 11155111,
            url: ETHEREUM_SEPOLIA_RPC ? ETHEREUM_SEPOLIA_RPC : 'wss://ethereum-sepolia-rpc.publicnode.com',
            accounts: [PRIVATE_KEY ? PRIVATE_KEY : ''],
            verify: {
                etherscan: {
                    apiKey: ETHERSCAN_API_KEY,
                },
            },
        },
        ethereum: {
            chainId: 1,
            url: ETHEREUM_RPC ? ETHEREUM_RPC : 'wss://ethereum-rpc.publicnode.com',
            accounts: [PRIVATE_KEY ? PRIVATE_KEY : ''],
            verify: {
                etherscan: {
                    apiKey: ETHERSCAN_API_KEY,
                },
            },
        },
        hardhat: {
            allowUnlimitedContractSize: true,
        },
    },
    etherscan: {
        apiKey: {
            arbitrum_sepolia: ARBISCAN_API_KEY ? ARBISCAN_API_KEY : '',
            arbitrum: ARBISCAN_API_KEY ? ARBISCAN_API_KEY : '',
            ethereum_sepolia: ETHERSCAN_API_KEY ? ETHERSCAN_API_KEY : '',
            ethereum: ETHERSCAN_API_KEY ? ETHERSCAN_API_KEY : '',
        },
        customChains: [
            {
                network: 'arbitrum_sepolia',
                chainId: 421614,
                urls: {
                    apiURL: 'https://api-sepolia.arbiscan.io/api',
                    browserURL: 'https://sepolia.arbiscan.io',
                },
            },
            {
                network: 'arbitrum',
                chainId: 42161,
                urls: {
                    apiURL: 'https://api.arbiscan.io/api',
                    browserURL: 'https://arbiscan.io/',
                },
            },
            {
                network: 'ethereum_sepolia',
                chainId: 11155111,
                urls: {
                    apiURL: 'https://api-sepolia.etherscan.io/api',
                    browserURL: 'https://sepolia.etherscan.io/',
                },
            },
            {
                network: 'ethereum',
                chainId: 1,
                urls: {
                    apiURL: 'https://api.etherscan.io/api',
                    browserURL: 'https://etherscan.io/',
                },
            },
        ],
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
    sourcify: {
        enabled: true,
    },
}

export default config
