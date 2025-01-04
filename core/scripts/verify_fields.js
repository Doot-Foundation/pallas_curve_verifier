const { Client } = require("mina-signer");
const { Signature, PublicKey } = require("o1js");
const client = new Client({ network: "testnet" });
const keypair = {
  privateKey: "EKEEa7Kzjh5ttuSzyjWZF9NEtZrQpsC3taNwKfi8U1nud3MwKvNs",
  publicKey: "B62qj2vSpa1MEXNPZAkLdEzQdRS9iE8NhhRfpqLCAvW6QCPi8fxAYnM",
};

async function main() {
  const Verifier = await ethers.getContractFactory(
    "PallasFieldsSignatureVerifier"
  );

  const verifier = Verifier.attach(
    "0x643aDFd52cB8c0cb4c3850BF97468b0EFBE71b25"
  );

  const vfId = await verifier.vfCounter();
  console.log("Current ID :", vfId);

  let vfState = await verifier.getVFState(vfId);
  console.log("Read result before step_0 :", vfState);

  const fields = [1n, 2n, 0n, 98n, 234958n, 54398n, 5493867n, 93298234n];
  const signedFields = client.signFields(fields, keypair.privateKey);
  const signatureObject = Signature.fromBase58(signedFields.signature);
  const s = signatureObject.s.toBigInt();
  const r = signatureObject.r.toBigInt();

  const signer = PublicKey.fromBase58(signedFields.publicKey);
  const signerFull = signer.toGroup();

  const result = client.verifyFields({
    data: signedFields.data,
    signature: signedFields.signature,
    publicKey: signedFields.publicKey,
  });

  let txn = await verifier.step_0_VF_assignValues(
    { x: signerFull.x.toString(), y: signerFull.y.toString() },
    { r: r, s: s },
    signedFields.data,
    false
  );
  console.log("Assignment Transaction hash:", txn.hash);
  await txn.wait();
  console.log("Transaction confirmed!");

  txn = await verifier.step_1_VF(vfId);
  await txn.wait();

  txn = await verifier.step_2_VF(vfId);
  await txn.wait();

  txn = await verifier.step_3_VF(vfId);
  await txn.wait();

  txn = await verifier.step_4_VF(vfId);
  await txn.wait();

  txn = await verifier.step_5_VF(vfId);
  await txn.wait();

  txn = await verifier.step_6_VF(vfId);
  await txn.wait();

  vfState = await verifier.getVFState(0);
  console.log("Mina-Signer Verdict :", result);
  console.log("Smart Contract Verdict :", vfState[2]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
