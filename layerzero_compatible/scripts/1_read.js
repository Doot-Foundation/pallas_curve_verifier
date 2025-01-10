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

    // Get verification type from user
    const typeInput = await question('Enter verification type (f/m): ');
    let verifyType;
    if (typeInput.toLowerCase() === 'f') {
        verifyType = 2; // fields
    } else if (typeInput.toLowerCase() === 'm') {
        verifyType = 1; // message
    } else {
        console.log('Invalid type. Please enter "f" for fields or "m" for message');
        rl.close();
        return;
    }

    // Get ID from user
    const idInput = await question('Enter ID (number): ');
    const id = parseInt(idInput);
    if (isNaN(id)) {
        console.log('Invalid ID. Please enter a number');
        rl.close();
        return;
    }

    // Get mode from user
    console.log('\nAvailable modes:');
    console.log('0: Conservative (20 Fields/100 Chars)');
    console.log('1: Default (50 Fields/250 Chars)');
    console.log('2: Optimistic (100 Fields/500 Chars)');

    const modeInput = await question('Enter mode (0/1/2): ');
    const mode = parseInt(modeInput);

    if (isNaN(mode) || mode < 0 || mode > 2) {
        console.log('Invalid mode. Please enter 0, 1, or 2');
        rl.close();
        return;
    }

    // Get quote
    const quote = await receiver.quoteAuto(verifyType, id, mode, false);
    const weiValue = BigInt(quote[0][2]);
    console.log('\nQuote:');
    console.log(weiValue.toString(), 'Wei');
    console.log(Number(weiValue) / 1e18, 'ETH');

    // Ask for confirmation
    const answer = await question('\nDo you want to continue? (y/n): ');

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
    const txn = await receiver.readBytesCompressedAuto(verifyType, id, mode, false, {
        value: weiValue,
    });
    console.log('Transaction hash:', txn.hash);
    await txn.wait(1);
    console.log('Transaction confirmed');

    rl.close();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
