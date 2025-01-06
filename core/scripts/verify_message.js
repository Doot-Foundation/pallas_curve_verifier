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
    "0x5790918c7db60C9c57dc1031FAf5f672EB22b4fC"
  );

  const vmId = await verifier.vmCounter();
  console.log("Current ID :", vmId);

  const message =
    "OHQBntWLxiMLLeRBIhBcEEvuzy6kEhhXaOVfN7TNvVUgupXZqeeoysxlrQ8zsn0KJ1sOcDQnUNYiZ2bsJgAVFaj3s4mp2O0R1232";
  console.log(message.length);
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
  console.log("step_1 confirmed!");

  txn = await verifier.step_2_VM(vmId);
  await txn.wait();
  console.log("step_2 confirmed!");

  txn = await verifier.step_3_VM(vmId);
  await txn.wait();
  console.log("step_3 confirmed!");

  txn = await verifier.step_4_VM(vmId);
  await txn.wait();
  console.log("step_4 confirmed!");

  txn = await verifier.step_5_VM(vmId);
  await txn.wait();
  console.log("step_5 confirmed!");

  txn = await verifier.step_6_VM(vmId);
  await txn.wait();
  console.log("step_6 confirmed!");

  let vmState = await verifier.getVMState(vmId);
  console.log("Mina-Signer Verdict :", result);
  console.log("Smart Contract Verdict :", vmState[2]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
