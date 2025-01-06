const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x68123E0627eA88cD114e92469303e1ABD4E35E9D');

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
    console.log(txn.hash);
    await txn.wait(1);

    console.log('All success!');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
