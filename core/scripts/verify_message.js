const { Client } = require("mina-signer");
const { PublicKey } = require("o1js");
const client = new Client({ network: "mainnet" });
const keypair = {
  privateKey: "EKEEa7Kzjh5ttuSzyjWZF9NEtZrQpsC3taNwKfi8U1nud3MwKvNs",
  publicKey: "B62qj2vSpa1MEXNPZAkLdEzQdRS9iE8NhhRfpqLCAvW6QCPi8fxAYnM",
};

async function main() {
  const Verifier = await ethers.getContractFactory(
    "PallasMessageSignatureVerifier"
  );

  const verifier = Verifier.attach(
    "0xB352B0dE8AF1e27a0fc927c1aD38BdB1bc4FCf40"
  );

  const vmId = await verifier.vmCounter();
  console.log("Current ID :", vmId);

  let vmState = await verifier.getVMState(vmId);
  console.log("Read result before step_0 :", vmState);

  const message =
    "Hello! THIS IS THE VERY FIRST TXN AND I AM VERY EXCITED. LETS FUCKING GOOOOO!";
  const signedMessage = client.signMessage(message, keypair.privateKey);
  const s = BigInt(signedMessage.signature.scalar);
  const r = BigInt(signedMessage.signature.field);

  const signer = PublicKey.fromBase58(signedMessage.publicKey);
  const signerFull = signer.toGroup();

  const result = client.verifyMessage({
    data: signedMessage.data,
    signature: signedMessage.signature,
    publicKey: signedMessage.publicKey,
  });

  let txn = await verifier.step_0_VM_assignValues(
    { x: signerFull.x.toString(), y: signerFull.y.toString() },
    { r: r, s: s },
    message,
    true //mainnet
  );
  console.log("Assignment Transaction hash:", txn.hash);
  await txn.wait();
  console.log("Transaction confirmed!");

  txn = await verifier.step_1_VM(vmId);
  await txn.wait();

  txn = await verifier.step_2_VM(vmId);
  await txn.wait();

  txn = await verifier.step_3_VM(vmId);
  await txn.wait();

  txn = await verifier.step_4_VM(vmId);
  await txn.wait();

  txn = await verifier.step_5_VM(vmId);
  await txn.wait();

  txn = await verifier.step_6_VM(vmId);
  await txn.wait();

  vmState = await verifier.getVMState(0);
  console.log("Mina-Signer Verdict :", result);
  console.log("Smart Contract Verdict :", vmState[2]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
