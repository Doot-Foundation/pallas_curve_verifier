const readline = require("readline");

async function promptForVMId() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question("Please enter the VM ID: ", (answer) => {
      rl.close();
      resolve(parseInt(answer));
    });
  });
}

async function main() {
  // Get VM ID from user prompt
  const vmId = await promptForVMId();

  // Validate the input
  if (isNaN(vmId)) {
    throw new Error("Please provide a valid VM ID as a number.");
  }

  const Verifier = await ethers.getContractFactory(
    "PallasMessageSignatureVerifier"
  );

  const verifier = Verifier.attach(
    "0xB352B0dE8AF1e27a0fc927c1aD38BdB1bc4FCf40"
  );

  const vmState = await verifier.getVMState(vmId);
  console.log(`State on-chain for VM ID ${vmId}:`, vmState);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
