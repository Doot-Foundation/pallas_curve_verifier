const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0xD15444a7ff0564AD8b283a94e8033F1ce31cd2E9');

    // Type (message/fields), id, mode, payInLz
    let quote = await receiver.quoteAuto(2, 0, 0, false);
    console.log(quote[0][2].toString());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
