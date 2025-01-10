# Each directory is a Hardhat project.

```shell
cd core/
npm install
npx hardhat test
```

```shell
cd layerzero_compatible/
npm install
```

# Order of execution

The following files are made to help you understand the execution flow. You can edit the files anytime to manually alter the
input data.
Before getting started, make sure you have populated and `.env` file following the pattern under `.env.example`.

The complete execution cycle to get started is as follows :

### core/ - Verification Layer on L2

- `npx hardhat run scripts/verify_fields.js --network arbitrum` (For Fields. Alter the fields var according to you.)
- `npx hardhat run scripts/verify_message.js --network arbitrum` (For Message. Alter the message var according to you.)
- `npx hardhat run scripts/get_vfState.js --network arbitrum` (To view the whole state.)
- `npx hardhat run scripts/get_vmState.js --network arbitrum` (To view the whole state.)
- `npx hardhat run scripts/get_fieldsBytes.js --network arbitrum` (To view the bytes formatted fields state. Only includes main states.)
- `npx hardhat run scripts/get_messageBytes.js --network arbitrum` (To view the bytes formatted message state. Only includes main states.)

### layerzero_compatible/ - Data availability on L1 (LayerZero OAppRead)

Automatic flow :

- `npx hardhat run scripts/1_read.js --network ethereum` (To get different default limits for the data to be read.)
- `npx hardhat run scripts/2_view.js --network ethereum`

Manual flow :

- `npx hardhat deploy --tags param` (To get more tightly bound limits for read(), Takes input data generated by get_fieldsBytes.js/get_messageBytes.js)
- `npx hardhat run scripts/1_readManual.js --network ethereum` (Takes generated by above.)
- `npx hardhat run scripts/2_view.js --network ethereum`

Note : For every operation related to reads, you can visit https://layerzeroscan.com/ for more info.
