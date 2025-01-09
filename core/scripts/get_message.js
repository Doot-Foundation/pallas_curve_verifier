async function main() {
  const Verifier = await ethers.getContractFactory(
    "PallasMessageSignatureVerifier"
  );

  const verifier = Verifier.attach(
    "0xB352B0dE8AF1e27a0fc927c1aD38BdB1bc4FCf40"
  );

  let vmId = 2;
  const vmState = await verifier.getVMState(vmId);
  console.log("State on-chain:", vmState);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
