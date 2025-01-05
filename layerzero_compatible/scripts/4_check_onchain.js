const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0xD15444a7ff0564AD8b283a94e8033F1ce31cd2E9');

    // Type (message/fields), id, mode, payInLz
    const value = await receiver.getVFIdToData(0);
    console.log(value);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
