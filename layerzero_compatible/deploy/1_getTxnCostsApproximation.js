module.exports = async ({ getNamedAccounts, deployments, ethers }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const test = await deploy('LzReceiveParametersDiscovery', {
        from: deployer,
        args: [],
        log: true,
    });

    console.log('Test deployed to:', test.address);

    const Receiver = await ethers.getContractFactory('LzReceiveParametersDiscovery');
    const receiver = Receiver.attach(test.address);

    /// Enter your data received by executing core/scripts/get_fieldsBytes.js OR core/scripts/get_fieldsBytes.js
    const testData = '0x000';

    /// Prepare data how its received through lzReceive
    const preparedData = await receiver.lzReceive_0(testData);

    const lzReceiveGasEstimate = await receiver.estimateGas.lzReceive(preparedData);
    const inflatedGasEstimate = lzReceiveGasEstimate + lzReceiveGasEstimate / 10;

    /// =====================================================================================================
    /// NOTE : These can be plugged directly with the readBytesCompressedManual for a more accurate txn cost.
    /// =====================================================================================================
    console.log('Calldata size :', preparedData.length());
    /// Estimate - Add 10% to the amount for confirmed execution since the original logic is a teeny tiny bit big.
    console.log('Estimated lzReceive gasLimit :', lzReceiveGasEstimate.toString());
    console.log('Absolute confirmation lzReceive gasLimit :', inflatedGasEstimate.toString());

    let txn = await receiver.lzReceive(testData);
    await txn.wait();

    const value = await receiver.get(1);
    console.log(value);
};
module.exports.tags = ['test'];
