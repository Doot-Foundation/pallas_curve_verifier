const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x5d7A7c08Fa8f2eD91A440dB4989327b79CB12B28');

    // Type (message/fields), id, mode, payInLz
    let txn;
    txn = await receiver.updateConservativeModeParams(750000, 800, 2000);
    console.log(txn.hash);
    await txn.wait(1);
    txn = await receiver.updateDefaultModeParams(1500000, 1100, 3800);
    console.log(txn.hash);
    await txn.wait(1);
    txn = await receiver.updateOptimisticModeParams(2600000, 1600, 7000);
    console.log(txn.hash);
    await txn.wait(1);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports.tags = ['Receiver'];
