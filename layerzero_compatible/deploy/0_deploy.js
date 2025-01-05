module.exports = async ({ getNamedAccounts, deployments, ethers }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    /// TESTING FOR ARB SEPOLIA
    const receiverContract = await deploy('PallasVerificationReceiever', {
        from: deployer,
        args: [
            '0x6EDCE65403992e310A62460808c4b910D972f10f',
            deployer,
            '0x2c393870Ed13b8DF0ed2861fBdC109cc2B9bd35F',
            '0x5790918c7db60C9c57dc1031FAf5f672EB22b4fC',
        ],
        log: true,
        waitConfirmations: 5,
        verify: {
            etherscan: {
                apiKey: process.env.ARBISCAN_API_KEY,
            },
        },
    });

    console.log('PallasVerificationReceiever deployed to:', receiverContract.address);
};
module.exports.tags = ['Receiver'];
