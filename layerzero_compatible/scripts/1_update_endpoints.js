const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0xD15444a7ff0564AD8b283a94e8033F1ce31cd2E9');

    let txn;

    txn = await receiver.updateReadFromEndpointId(40231);
    console.log(txn.hash);
    await txn.wait(1);
    txn = await receiver.updateReadFromEndpointAddress('0x6EDCE65403992e310A62460808c4b910D972f10f');
    console.log(txn.hash);
    await txn.wait(1);

    txn = await receiver.updateReadToEndpointId(40231);
    console.log(txn.hash);
    await txn.wait(1);
    txn = await receiver.updateReadToEndpointAddress('0x6EDCE65403992e310A62460808c4b910D972f10f');
    console.log(txn.hash);
    await txn.wait(1);

    txn = await receiver.setReadChannel(4294967295, true);
    await txn.wait(1);

    console.log('All success!');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
