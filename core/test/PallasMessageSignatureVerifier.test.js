const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { PublicKey, PrivateKey } = require("o1js");
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

      const message =
        "Sign this message to prove you have access to this wallet. You will be logged in automatically.";

      // Get signed message
      const signedMessage = client.signMessage(message, keypair.privateKey);

      const altMessage =
        "Sign this message to prove you have access to this wallet. You will be logged in automatically at dashboard/";

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

    it("Should return isValid=false in case invalid data sent.", async function () {
      const { verifier, signedMessage, altSignedMessage, client } =
        await loadFixture(deployAndSetupMessage);

      /// 3 TEST CASES : signedMessage is our original object. altSignedMessage is our alternate object.
      ///   1. DIFFERENT SIGNATURE
      ///   2. DIFFERENT DATA
      ///   3. DIFFERENT PUBLIC KEY

      /// DIFFERENT SIGNATURE -------------------------------------------------
      let s = BigInt(altSignedMessage.signature.scalar);
      let r = BigInt(altSignedMessage.signature.field);

      let signer = PublicKey.fromBase58(signedMessage.publicKey);
      let signerFull = signer.toGroup();

      let result = client.verifyMessage({
        data: signedMessage.data,
        signature: altSignedMessage.signature,
        publicKey: signedMessage.publicKey,
      });

      let vmId = 0;

      let txn;
      txn = await verifier.step_0_VM_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        signedMessage.data,
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

      let finalObject = await verifier.getVMState(vmId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);

      /// DIFFERENT DATA -------------------------------------------------
      s = BigInt(signedMessage.signature.scalar);
      r = BigInt(signedMessage.signature.field);

      signer = PublicKey.fromBase58(signedMessage.publicKey);
      signerFull = signer.toGroup();

      result = client.verifyMessage({
        data: altSignedMessage.data,
        signature: signedMessage.signature,
        publicKey: signedMessage.publicKey,
      });

      vmId = 1;

      txn;
      txn = await verifier.step_0_VM_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        altSignedMessage.data,
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

      finalObject = await verifier.getVMState(vmId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);

      /// DIFFERENT PUBLIC KEY -------------------------------------------------
      s = BigInt(signedMessage.signature.scalar);
      r = BigInt(signedMessage.signature.field);

      const randomPK = PrivateKey.random();
      const random = randomPK.toPublicKey();
      const randomFull = random.toGroup();

      result = client.verifyMessage({
        data: signedMessage.data,
        signature: signedMessage.signature,
        publicKey: random.toBase58(),
      });

      vmId = 2;

      txn;
      txn = await verifier.step_0_VM_assignValues(
        { x: randomFull.x.toString(), y: randomFull.y.toString() },
        { r: r, s: s },
        signedMessage.data,
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

      finalObject = await verifier.getVMState(vmId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);
    });

    it("Should return isValid=false in case inverted network bool sent as parameter.", async function () {
      const { verifier, signedMessage } = await loadFixture(
        deployAndSetupMessage
      );

      /// Creating a testnet client.
      const altClient = new Client({ network: "testnet" });

      let s = BigInt(signedMessage.signature.scalar);
      let r = BigInt(signedMessage.signature.field);

      let signer = PublicKey.fromBase58(signedMessage.publicKey);
      let signerFull = signer.toGroup();

      /// The result will be false since the data was signed for mainnet.
      let result = altClient.verifyMessage({
        data: signedMessage.data,
        signature: signedMessage.signature,
        publicKey: signedMessage.publicKey,
      });

      let vmId = 0;

      let txn;
      /// Choosing testnet for the verification. Should return false finally.
      txn = await verifier.step_0_VM_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        signedMessage.data,
        false // testnet
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

      let finalObject = await verifier.getVMState(vmId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);
    });
  });
});
