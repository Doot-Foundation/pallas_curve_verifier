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

    // Get calldata size from user
    const calldataSizeInput = await question('Enter calldata size (number): ');
    const calldataSize = parseInt(calldataSizeInput);
    if (isNaN(calldataSize)) {
        console.log('Invalid calldata size. Please enter a number');
        rl.close();
        return;
    }

    // Get gas limit from user
    const gasLimitInput = await question('Enter gas limit (number): ');
    const gasLimit = parseInt(gasLimitInput);
    if (isNaN(gasLimit)) {
        console.log('Invalid gas limit. Please enter a number');
        rl.close();
        return;
    }

    // Get quote
    const quote = await receiver.quote(verifyType, id, calldataSize, gasLimit, false);
    const weiValue = BigInt(quote[0][2]);
    console.log(weiValue.toString(), 'Wei');
    console.log(Number(weiValue) / 1e18, 'ETH');

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
    const txn = await receiver.readBytesCompressedManual(verifyType, id, calldataSize, gasLimit, false, {
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
