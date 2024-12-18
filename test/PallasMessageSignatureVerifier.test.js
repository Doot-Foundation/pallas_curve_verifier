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

      const message = "50505050505050505050505050505050505050505050505050";

      // Get signed message
      const signedMessage = client.signMessage(message, keypair.privateKey);

      const altMessage = "50505050505050505050505050505050505050505050505069";

      const altSignedMessage = client.signMessage(
        altMessage,
        keypair.privateKey
      );

      return {
        verifier,
        signedMessage,
        keypair,
        client,
        message,
        altMessage,
        altSignedMessage,
      };
    }

    it("Should verify signature through all steps in case valid.", async function () {
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

      let txn;
      txn = await verifier.step_0_VM_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        message,
        true
      );
      await txn.wait();

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
      expect(finalObject[2]).to.equal(result);
      expect(finalObject[2]).to.equal(true);
    });

    // it("Should return isValid=false in case invalid.", async function () {
    //   const { verifier, signedMessage, altSignedMessage, client, altMessage } =
    //     await loadFixture(deployAndSetupMessage);

    //   // const signatureObject = Signature.fromBase58(signedMessage.signature);
    //   const s = BigInt(signedMessage.signature.scalar);
    //   const r = BigInt(signedMessage.signature.field);

    //   const signer = PublicKey.fromBase58(signedMessage.publicKey);
    //   const signerFull = signer.toGroup();

    //   const result = client.verifyMessage({
    //     data: altSignedMessage.data,
    //     publicKey: signedMessage.publicKey,
    //     signature: signedMessage.signature,
    //   });

    //   const vmId = 0;

    //   let txn;
    //   txn = await verifier.step_0_VM_assignValues(
    //     { x: signerFull.x.toString(), y: signerFull.y.toString() },
    //     { r: r, s: s },
    //     altMessage,
    //     true
    //   );
    //   await txn.wait();

    //   txn = await verifier.step_1_VM(vmId);
    //   await txn.wait();

    //   txn = await verifier.step_2_VM(vmId);
    //   await txn.wait();

    //   txn = await verifier.step_3_VM(vmId);
    //   await txn.wait();

    //   txn = await verifier.step_4_VM(vmId);
    //   await txn.wait();

    //   txn = await verifier.step_5_VM(vmId);
    //   await txn.wait();

    //   txn = await verifier.step_6_VM(vmId);
    //   await txn.wait();

    //   const finalObject = await verifier.getVMState(vmId);
    //   expect(finalObject[2]).to.equal(result);
    //   expect(finalObject[2]).to.equal(false);
    // });
  });
});
