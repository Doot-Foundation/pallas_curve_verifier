module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const receiverContract = await deploy('PallasVerificationReceiever', {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: 5,
    });

    console.log('PallasVerificationReceiever deployed to:', receiverContract.address);
};
module.exports.tags = ['MyContract'];
