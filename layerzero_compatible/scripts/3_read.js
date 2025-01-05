const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0xD15444a7ff0564AD8b283a94e8033F1ce31cd2E9');

    // Type (message/fields), id, mode, payInLz
    const quote = await receiver.quoteAuto(2, 0, 0, false);
    const weiValue = BigInt(quote[0][2]) + 100000000000000n; // Taking some extra
    console.log(weiValue);
    // verifyType,  uint256 id,  MODE mode,  bool payInLzToken
    const txn = await receiver.readBytesCompressedAuto(2, 0, 0, false, {
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
