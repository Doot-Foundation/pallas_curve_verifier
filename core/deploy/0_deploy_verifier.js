module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const fieldsContract = await deploy("PallasFieldsSignatureVerifier", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 5,
  });

  const messageContract = await deploy("PallasMessageSignatureVerifier", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 5,
  });

  console.log(
    "PallasFieldsSignatureVerifier deployed to:",
    fieldsContract.address
  );
  console.log(
    "PallasMessageSignatureVerifier deployed to:",
    messageContract.address
  );
};
module.exports.tags = ["Verifiers"];
