const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x5d7A7c08Fa8f2eD91A440dB4989327b79CB12B28');

    let txn;

    // ARB SEPOLIA
    // txn = await receiver.updateReadFromEndpointId(40231);
    // console.log(txn.hash);
    // await txn.wait(1);
    // txn = await receiver.updateReadFromEndpointAddress('0x6EDCE65403992e310A62460808c4b910D972f10f');
    // console.log(txn.hash);
    // await txn.wait(1);

    // txn = await receiver.updateReadToEndpointId(40161);
    // console.log(txn.hash);
    // await txn.wait(1);
    // txn = await receiver.updateReadToEndpointAddress('0x6EDCE65403992e310A62460808c4b910D972f10f');
    // console.log(txn.hash);
    // await txn.wait(1);

    /// ETH SEPOLIA
    // txn = await receiver.updateReadFromEndpointId(40231);
    // console.log(txn.hash);
    // await txn.wait(1);
    // txn = await receiver.updateReadFromEndpointAddress('0x6EDCE65403992e310A62460808c4b910D972f10f');
    // console.log(txn.hash);
    // await txn.wait(1);

    /// COMMMON FOR ALL
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
