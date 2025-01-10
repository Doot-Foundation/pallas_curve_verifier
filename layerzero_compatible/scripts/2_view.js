const readline = require('readline');

const { ethers } = require('hardhat');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

const question = (query) => new Promise((resolve) => rl.question(query, resolve));

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x5d7A7c08Fa8f2eD91A440dB4989327b79CB12B28');

    // Get verification type for viewing
    const typeInput = await question('Enter type to view (f/m): ');
    const idInput = await question('Enter ID to view: ');
    const id = parseInt(idInput);

    if (isNaN(id)) {
        console.log('Invalid ID. Please enter a number');
        rl.close();
        return;
    }

    if (typeInput.toLowerCase() === 'f') {
        const valueF = await receiver.getVFIdToData(id);
        console.log('Fields Data:', valueF);
    } else if (typeInput.toLowerCase() === 'm') {
        const valueM = await receiver.getVMIdToData(id);
        console.log('Message Data:', valueM);
    } else {
        console.log('Invalid type. Please enter "f" for fields or "m" for message');
    }

    rl.close();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports.tags = ['Receiver'];
