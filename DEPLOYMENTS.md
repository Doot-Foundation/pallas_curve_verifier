# DEPLOYMENT V1

V1 is the hardcoded contract without the cheap data availability hybird model.
The gas fee in this version on Ethereum is practically insane so pivoting to Arbitrum is required.

## ARBITRUM SEPOLIA

PallasFieldsSignatureVerifier deployed to : https://sepolia.arbiscan.io/address/0x2c393870Ed13b8DF0ed2861fBdC109cc2B9bd35F

PallasMessageSignatureVerifier deployed to: https://sepolia.arbiscan.io/address/0x5790918c7db60C9c57dc1031FAf5f672EB22b4fC

## ARBITRUM

PallasFieldsSignatureVerifier deployed to: https://arbiscan.io/address/0x643aDFd52cB8c0cb4c3850BF97468b0EFBE71b25

PallasMessageSignatureVerifier deployed to: https://arbiscan.io/address/0xB352B0dE8AF1e27a0fc927c1aD38BdB1bc4FCf40

# DEPLOYMENT V2

The Hybrid Model - Computation on Arbitrum and all the important state made available on Ethereum
counterpart with much less costs.

Using layerzero for it. lzRead to be specific.

## TESTNET

ARB SEPOLIA - PallasFieldsSignatureVerifier deployed to : https://sepolia.arbiscan.io/address/0x2c393870Ed13b8DF0ed2861fBdC109cc2B9bd35F

ARB SEPOLIA - PallasMessageSignatureVerifier deployed to: https://sepolia.arbiscan.io/address/0x5790918c7db60C9c57dc1031FAf5f672EB22b4fC

---

Both of these points to the PallasFieldsSignatureVerifier/PallasMessageSignatureVerifier deployed on Arbitrum Sepolia.

ARB SEPOLIA - PallasVerificationReceiever deployed to: https://sepolia.arbiscan.io/address/0x68123E0627eA88cD114e92469303e1ABD4E35E9D ✅(Successful Reads)

ETH SEPOLIA - PallasVerificationReceiever deployed to: https://sepolia.etherscan.io/address/0xfccB27f368F721DFA4aEAbba8b95Be50142bdAa9 ✅(Successful Reads)

## MAINNET

### ARBITRUM - BUSINESS LOGIC LAYER

PallasFieldsSignatureVerifier deployed to: https://arbiscan.io/address/0x643aDFd52cB8c0cb4c3850BF97468b0EFBE71b25

PallasMessageSignatureVerifier deployed to: https://arbiscan.io/address/0xB352B0dE8AF1e27a0fc927c1aD38BdB1bc4FCf40

### ETHEREUM - DATA REPLICATION LAYER

Points to the PallasFieldsSignatureVerifier/PallasMessageSignatureVerifier deployed on Arbitrum Mainnet.

PallasVerificationReceiever deployed to: https://etherscan.io/address/0x5d7A7c08Fa8f2eD91A440dB4989327b79CB12B28
✅(Successful Reads)
