# verifyFields() mina-signer

# Pallas Curve Field Elements Signature Verification in Solidity

An implementation of signature verification for field elements over the Pallas curve, matching o1js behavior.

## Overview

The verification process is split into sequential steps for a clear verification path and easier debugging. The contract maintains state between steps, allowing inspection at any point.

## Implementation Details

### State Structure

```solidity
struct VerifyFieldsState {
   bool init;                // Initialization tracker
   bool mainnet;            // Network flag
   uint8 atStep;            // Current step
   Point publicKey;         // Public key point
   Signature signature;     // Signature (r,s)
   uint256[] fields;        // Fields to verify
   string prefix;           // Network prefix
   uint256 messageHash;     // Computed hash
   Point pkInGroup;         // Public key on curve
   Point sG;                // s*G calculation
   Point ePk;               // e*pk calculation
   Point R;                 // Final point
   bool isValid;            // Result
}
```

### Verification Steps

## Step 0: Initialize State

```solidity
function step_0_VF_assignValues(
    Point publicKey,
    Signature signature,
    uint256[] fields,
    bool network
) external returns (uint256)
```

- Validates public key is on curve
- Sets initial state values
- Returns state identifier
- Sets network-specific prefix:
  - Mainnet: "MinaSignatureMainnet"
  - Testnet: "CodaSignature**\*\*\***"

## Step 1: Compute Message Hash

```solidity
function step_2_VF(uint256 vfId)
```

- Converts input fields to Poseidon hash
- Critical: Maintains field order [fields, pk.x, pk.y, signature.r]
- Applies network prefix to hash

## Step 2: Convert Public Key

```solidity
function step_2_VF(uint256 vfId)
```

- Decompresses public key to curve point
- Solves y² = x³ + 5 for y coordinate

## Step 3: Compute s\*G

```solidity
function step_3_VF(uint256 vfId)
```

- Multiplies generator G by signature scalar s
- Important: No modulo reduction before multiplication

## Step 4: Compute e\*PK

```solidity
function step_4_VF(uint256 vfId)
```

- Multiplies public key by message hash e

## Step 5: Compute R

```solidity
function step_5_VF(uint256 vfId)
```

- Calculates R = sG - ePk via point addition

## Step 6: Verify Signature

```solidity
function step_6_VF(uint256 vfId)
```

- Checks R.x matches signature.r
- Verifies R.y is even
- Returns final validity

# Core Mathematical Operations

## Point Arithmetic

- Point addition using projective coordinates
- Point doubling optimized for a=0 curve
- Scalar multiplication without modular reduction

## Field Operations

- Modular arithmetic in Fp
- Square root computation
- Field inversions
- Poseidon hash operations

## Critical Implementation Notes

### Scalar Multiplication

- Must not reduce scalar by SCALAR_MODULUS before multiplication
- Matches o1js implementation exactly

### Poseidon Hash

- Precise field element ordering
- Network prefix application matches o1js
- Identical round constants and MDS matrix

### Generator Point

- Must use exact coordinates from o1js
- G.x = 1
- G.y = 0x1b74b5a30a12937c53dfa9f06378ee548f655bd4333d477119cf7a23caed2abb

### Projective Coordinates

- Used for efficient point arithmetic
- Careful conversion to/from affine coordinates

### Testing

The implementation has been verified against o1js test vectors, ensuring:

- Hash computations match
- Point arithmetic matches
- Final verification results match

# References

- o1js Implementation
- Mina Protocol Specifications
- Pallas Curve Parameters
