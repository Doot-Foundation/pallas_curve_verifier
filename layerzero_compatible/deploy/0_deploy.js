module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    /// ETHEREUM SEPOLIA TEST
    const receiverContract = await deploy('PallasVerificationReceiever', {
        from: deployer,
        args: [
            '0x1a44076050125825900e736c501f859c50fE728c', // ETH MAINNET ENDPOINT ADDRESS
            deployer,
            '0x643aDFd52cB8c0cb4c3850BF97468b0EFBE71b25', // ARB MAINNET VF
            '0xB352B0dE8AF1e27a0fc927c1aD38BdB1bc4FCf40', // ARB MAINNET VM
        ],
        log: true,
        waitConfirmations: 5,
        verify: {
            etherscan: {
                apiKey: process.env.ETHERSCAN_API_KEY,
            },
        },
    });

    console.log('PallasVerificationReceiever deployed to:', receiverContract.address);
};
module.exports.tags = ['Receiver'];
