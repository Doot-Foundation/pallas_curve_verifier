# Gas Analysis Report (18/12/24)

## Network Gas Prices

- Arbitrum: 0.00000000001 ETH (0.01 Gwei)
- Ethereum: 0.00000001105 ETH (11.5 Gwei)

## Deployment Costs

| Contract      | Gas Used   |
| ------------- | ---------- |
| VerifyFields  | 7,294,407  |
| VerifyMessage | 10,823,527 |

## Large Input Test (100 Fields/Characters)

| Operation       | Average Gas | Arbitrum Cost ($) | Ethereum Cost ($) |
| --------------- | ----------- | ----------------- | ----------------- |
| verifyFields()  | 47,427,040  | $1.89             | $2,096.27         |
| verifyMessage() | 10,671,675  | $0.42             | $471.68           |

_ETH price: $4000_

## Medium Input Test (50 Field/Character)

| Operation       | Average Gas | Arbitrum Cost ($) | Ethereum Cost ($) |
| --------------- | ----------- | ----------------- | ----------------- |
| verifyFields()  | 26,522,054  | $1.06             | $1172.27          |
| verifyMessage() | 8,374,215   | $0.335            | $370.14           |

_ETH price: $4000_

## Minimal Input Test (1 Field/Character)

| Operation       | Average Gas | Arbitrum Cost ($) | Ethereum Cost ($) |
| --------------- | ----------- | ----------------- | ----------------- |
| verifyFields()  | 5,646,006   | $0.226            | $249.55           |
| verifyMessage() | 6,377,241   | $0.255            | $281.87           |

_ETH price: $4000_

# How to get costs like Arbitrum but data availability on Ethereum ?

L1 <-> L2 Cross Messaging with the help of LayerZero.

At step_6 of both verifyFields() and verifyMessage() we can optimize the data for cheaper bridge costs,
And make a call to the messaging interface in the middle.
Data to be sent on Ethereum :

```solidity
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
```

`https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts`

### Arbitrum Information :

```
ChainId       : 42161
EndpointId    : 30110
EndpointV2    : 0x1a44076050125825900e736c501f859c50fE728c
SendUln302    : 0x975bcD720be66659e3EB3C0e4F1866a3020E493A
ReceiveUln302 : 0x7B9E184e07a6EE1aC23eAe0fe8D6Be2f663f05e6
SendUln301    : 0x5cDc927876031B4Ef910735225c425A7Fc8efed9
ReceiveUln301 : 0xe4DD168822767C4342e54e6241f0b91DE0d3c241
LZ Executor   : 0x31CAe3B7fB82d847621859fb1585353c5720660D
LZ Dead DVN   : 0x758C419533ad64Ce9D3413BC8d3A97B026098EC1
```

### Ethereum Mainnet

```
ChainId       : 1
EndpointId    : 30101
EndpointV2    : 0x1a44076050125825900e736c501f859c50fE728c
SendUln302    : 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1
ReceiveUln302 : 0xc02Ab410f0734EFa3F14628780e6e695156024C2
SendUln301    : 0xD231084BfB234C107D3eE2b22F97F3346fDAF705
ReceiveUln301 : 0x245B6e8FFE9ea5Fc301e32d16F66bD4C2123eEfC
LZ Executor   : 0x173272739Bd7Aa6e4e214714048a9fE699453059
LZ Dead DVN   : 0x747C741496a507E4B404b50463e691A8d692f6Ac
```
