const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { PublicKey } = require("o1js");
const { Client } = require("mina-signer");

describe("PallasMessageSignatureVerifier", function () {
  async function deployVerifierFixture() {
    const [deployer] = await ethers.getSigners();
    const PallasSignatureVerifier = await ethers.getContractFactory(
      "PallasMessageSignatureVerifier"
    );
    const verifier = await PallasSignatureVerifier.deploy();
    return { verifier, deployer };
  }

  describe("Message Signature Verification", function () {
    async function deployAndSetupMessage() {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Setup mina-signer
      const client = new Client({ network: "mainnet" });

      // const keypair = client.genKeys();
      const keypair = {
        privateKey: "EKEEa7Kzjh5ttuSzyjWZF9NEtZrQpsC3taNwKfi8U1nud3MwKvNs",
        publicKey: "B62qj2vSpa1MEXNPZAkLdEzQdRS9iE8NhhRfpqLCAvW6QCPi8fxAYnM",
      };

      const message = "MINA MINA MINA MINA MINA";

      // Get signed message
      const signedMessage = client.signMessage(message, keypair.privateKey);

      return { verifier, signedMessage, keypair, client, message };
    }

    it("Should verify message signature through all steps", async function () {
      const { verifier, signedMessage, client, message } = await loadFixture(
        deployAndSetupMessage
      );

      // const signatureObject = Signature.fromBase58(signedMessage.signature);
      const s = BigInt(signedMessage.signature.scalar);
      const r = BigInt(signedMessage.signature.field);

      const signer = PublicKey.fromBase58(signedMessage.publicKey);
      const signerFull = signer.toGroup();

      const result = client.verifyMessage({
        data: signedMessage.data,
        publicKey: signedMessage.publicKey,
        signature: signedMessage.signature,
      });

      const vmId = 0;

      console.log("\n");

      let txn;
      txn = await verifier.step_0_VM_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        message,
        true
      );
      await txn.wait();

      //   first = [
      //     5328350144166205084223774245058198666309664348635459768305312917086056785354n,
      //     15214731724107930304595906373487084110291887262136882623959435918484004667388n,
      //     22399519358931858664262538157042328690232277435337286643350379269028878354609n,
      //   ];
      //   second = [
      //     17759893084961407030675569585617643809183866065840518413549386374114484597013n,
      //     3222794424707540201664619026980620225213287395011536752171005623726004844932n,
      //     9765260016535305818550706533373743224545418931374699727670548161187365422125n,
      //   ];
      //   txn = await verifier.testDotProductWithSteps(first, second);
      //   await txn.wait();

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

      const finalObject = await verifier.getVMState(vmId);
      console.log(finalObject[6]);
      expect(finalObject[11]).to.equal(result);
    });
  });
});
