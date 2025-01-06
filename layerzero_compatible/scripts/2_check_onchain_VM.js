const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0x68123E0627eA88cD114e92469303e1ABD4E35E9D');

    const valueM = await receiver.getVMIdToData(9);
    console.log(valueM);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports.tags = ['Receiver'];
