const { ethers } = require('hardhat');

async function main() {
    const Receiver = await ethers.getContractFactory('PallasVerificationReceiever');
    const receiver = Receiver.attach('0xD15444a7ff0564AD8b283a94e8033F1ce31cd2E9');

    let vf_config = await receiver.CHAIN_CONFIG_VF();
    console.log(vf_config);
    let vm_config = await receiver.CHAIN_CONFIG_VM();
    console.log(vm_config);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
