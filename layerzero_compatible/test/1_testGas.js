module.exports = async ({ getNamedAccounts, deployments, ethers }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    /// TESTING FOR ARB SEPOLIA
    const test = await deploy('LzReceiveVFGasCost', {
        from: deployer,
        args: [],
        log: true,
    });

    console.log('Test deployed to:', test.address);

    const Receiver = await ethers.getContractFactory('LzReceiveVFGasCost');
    const receiver = Receiver.attach(test.address);

    const testData =
        '0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000d8302000000000000000000000000000000000000000000000000000000000000000900012459891433d71aae7930498bac67a1e8294fe9ca39396ae756a32948cf9a48111edc955588ef46f40977a21d7906ee317c3fd8f4836d946af8602c7bb722c1a3191643a145b0e62e92e6f911925a7432f2b16f193973d15c4549f25d0ee05bfd37ad071b6caf83fe4c70c5c876509f3dbb75de670725ee0e5b84a08d2834b9bc0c5902d9a0e9b55f25dbdcc59c42c32922c641bed5b1b9b5a4f73c4fcdaa41a5000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000640000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000003e3aeb4ae1383562f4b82261d969f7ac94ca3fffffffffffffff0000000000000000000000000000000000000000000000000000000000';
    const lzReceiveGasEstimate = await receiver.estimateGas.lzReceive(testData);
    console.log('Estimated lzReceive gas:', lzReceiveGasEstimate.toString());

    let txn = await receiver.lzReceive(testData);
    await txn.wait();

    const value = await receiver.get(1);
    console.log(value);
};
module.exports.tags = ['test'];
