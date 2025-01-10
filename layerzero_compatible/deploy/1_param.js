module.exports = async ({ getNamedAccounts, deployments, ethers }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    const getUserInput = () => {
        return new Promise((resolve) => {
            readline.question('Enter input data (solidity - bytes): ', (input) => {
                resolve(input);
            });
        });
    };

    const getId = () => {
        return new Promise((resolve) => {
            readline.question('Enter its unique id: ', (input) => {
                resolve(input);
            });
        });
    };

    const test = await deploy('LzReceiveParametersDiscovery', {
        from: deployer,
        args: [],
        log: true,
    });

    console.log('Test deployed to:', test.address);

    const Receiver = await ethers.getContractFactory('LzReceiveParametersDiscovery');
    const receiver = Receiver.attach(test.address);

    // Get testData from user input
    const testData = await getUserInput();
    const id = await getId();
    readline.close();

    // Validate that testData is not empty
    if (!testData) {
        console.error('Error: Test data cannot be empty');
        process.exit(1);
    }

    // Prepare data how its received through lzReceive
    const preparedData = await receiver.lzReceive_0(testData);
    console.log('\nPrepard :', preparedData, '\n');
    const lzReceiveGasEstimate = await receiver.estimateGas.lzReceive(preparedData);
    const inflatedGasEstimate = Math.floor(lzReceiveGasEstimate * 1.1);

    let txn = await receiver.lzReceive(preparedData);
    await txn.wait();

    let value;
    value = await receiver.getVM(id);
    if (value.verifyType != 0) console.log(value);

    value = await receiver.getVF(id);
    if (value.verifyType != 0) console.log(value);

    /// =====================================================================================================
    /// NOTE : These can be plugged directly with the readBytesCompressedManual for a more accurate txn cost.
    /// =====================================================================================================
    console.log('\nCalldata size :', preparedData.length);
    console.log('Estimated lzReceive gasLimit :', lzReceiveGasEstimate.toString());
    console.log('Absolute confirmation lzReceive gasLimit :', inflatedGasEstimate.toString());
    console.log();
};

module.exports.tags = ['param'];
