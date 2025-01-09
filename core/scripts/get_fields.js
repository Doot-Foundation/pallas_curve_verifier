async function main() {
  const Verifier = await ethers.getContractFactory(
    "PallasFieldsSignatureVerifier"
  );

  const verifier = Verifier.attach(
    "0x643aDFd52cB8c0cb4c3850BF97468b0EFBE71b25"
  );

  let vfId = 2;
  const vfState = await verifier.getVFState(vfId);
  console.log("State on-chain:", vfState);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
