# Gas Analysis Report (18/12/24)

## Network Gas Prices

- Arbitrum: 0.00000000001 ETH (0.01 Gwei)
- Ethereum: 0.00000001105 ETH (11.5 Gwei)

### At $4000 ETH

## Deployment Costs

| Contract      | Gas Used   | Arbitrum Cost ($) | Ethereum Cost ($) |
| ------------- | ---------- | ----------------- | ----------------- |
| VerifyFields  | 7,294,407  | $0.29             | $322.41           |
| VerifyMessage | 10,823,527 | $0.433            | $478.39           |

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
