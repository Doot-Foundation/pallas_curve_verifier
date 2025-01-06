const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x68123E0627eA88cD114e92469303e1ABD4E35E9D');

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
