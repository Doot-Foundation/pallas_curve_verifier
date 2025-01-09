const { Client } = require("mina-signer");
const { Signature, PublicKey } = require("o1js");
const client = new Client({ network: "mainnet" });
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

  let vfId = await verifier.vfCounter();
  console.log("Current ID :", vfId);

  const fields = [
    984932845237n,
    11299549834589n,
    65879389797321n,
    999345723232347n,
    9956483456821234n,
    12321343243427n,
    984932845237n,
    11299549834589n,
    65879389797321n,
    999345723232347n,
  ];
  console.log(fields.length);

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
  console.log("step_0 confirmed!");

  txn = await verifier.step_1_VF(vfId);
  await txn.wait();
  console.log("step_1 confirmed!");

  txn = await verifier.step_2_VF(vfId);
  await txn.wait();
  console.log("step_2 confirmed!");

  txn = await verifier.step_3_VF(vfId);
  await txn.wait();
  console.log("step_3 confirmed!");

  txn = await verifier.step_4_VF(vfId);
  await txn.wait();
  console.log("step_4 confirmed!");

  txn = await verifier.step_5_VF(vfId);
  await txn.wait();
  console.log("step_5 confirmed!");

  txn = await verifier.step_6_VF(vfId);
  await txn.wait();
  console.log("step_6 confirmed!");

  const vfState = await verifier.getVFState(vfId);
  console.log("Mina-Signer Verdict :", result);
  console.log("Smart Contract Verdict :", vfState[2]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
