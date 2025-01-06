const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x68123E0627eA88cD114e92469303e1ABD4E35E9D');

    // Type 1 message/2 fields, id, mode, payInLz
    const quote = await receiver.quoteAuto(1, 2, 0, false);
    const weiValue = BigInt(quote[0][2]);
    console.log(weiValue);
    // verifyType,  uint256 id,  MODE mode,  bool payInLzToken
    const txn = await receiver.readBytesCompressedAuto(1, 2, 0, false, {
        value: weiValue,
    });
    console.log(txn.hash);
    await txn.wait(1);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
