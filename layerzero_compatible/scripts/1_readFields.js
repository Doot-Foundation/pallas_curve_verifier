const readline = require('readline');

const { ethers } = require('hardhat');

// Create readline interface
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

// Promise wrapper for question
const question = (query) => new Promise((resolve) => rl.question(query, resolve));

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x5d7A7c08Fa8f2eD91A440dB4989327b79CB12B28');

    // Type (NULL/message/fields), id, mode, payInLz
    const quote = await receiver.quoteAuto(2, 2, 0, false);
    const weiValue = BigInt(quote[0][2]);
    console.log(weiValue.toString(), 'Wei');
    console.log(weiValue / 1000000000000000000n, 'ETH');

    // Ask for confirmation
    const answer = await question('Do you want to continue? (y/n): ');

    if (answer.toLowerCase() === 'n') {
        console.log('Transaction cancelled by user');
        rl.close();
        return;
    }

    if (answer !== 'y') {
        console.log('Invalid input. Please enter "y" or "n". Exiting...');
        rl.close();
        return;
    }

    // Proceed with transaction
    const txn = await receiver.readBytesCompressedAuto(2, 2, 0, false, {
        value: weiValue,
    });
    console.log(txn.hash);
    await txn.wait(1);

    // Close readline interface
    rl.close();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
