const readline = require("readline");

async function promptForVFId() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(
      "Please enter the VF ID for compressed bytes state: ",
      (answer) => {
        rl.close();
        resolve(parseInt(answer));
      }
    );
  });
}

async function main() {
  // Get VF ID from user prompt
  const vfId = await promptForVFId();

  // Validate the input
  if (isNaN(vfId)) {
    throw new Error("Please provide a valid VF ID as a number.");
  }

  const Verifier = await ethers.getContractFactory(
    "PallasFieldsSignatureVerifier"
  );

  const verifier = Verifier.attach(
    "0x643aDFd52cB8c0cb4c3850BF97468b0EFBE71b25"
  );

  const vfState = await verifier.getVFStateBytesCompressed(vfId);
  console.log(`Bytes State on-chain for VF ID ${vfId}:`, vfState);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
