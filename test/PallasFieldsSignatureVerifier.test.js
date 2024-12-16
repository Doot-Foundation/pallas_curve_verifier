const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { Signature, PrivateKey, PublicKey } = require("o1js");
const { Client } = require("mina-signer");

const FIELD_MODULUS =
  45064998451067251948035796725861806592124573483999999999999993n;

describe("PallasFieldsSignatureVerifier", function () {
  async function deployVerifierFixture() {
    const [deployer] = await ethers.getSigners();
    const PallasSignatureVerifier = await ethers.getContractFactory(
      "PallasFieldsSignatureVerifier"
    );
    const verifier = await PallasSignatureVerifier.deploy();
    return { verifier, deployer };
  }

  // describe("Public Key Verification", function () {
  //   it("Should verify valid public key", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const generatedPK = PrivateKey.random();
  //     const key = generatedPK.toPublicKey().toGroup();
  //     const point = {
  //       x: BigInt(key.x.toString()),
  //       y: BigInt(key.y.toString()),
  //     };

  //     const isValid = await verifier.isValidPublicKey(point);
  //     expect(isValid).to.be.true;
  //   });

  //   it("Should reject invalid public key point", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const invalidPoint = { x: 1n, y: 1n };
  //     const isValid = await verifier.isValidPublicKey(invalidPoint);
  //     expect(isValid).to.be.false;
  //   });
  // });

  // describe("Point Conversion", function () {
  //   it("Should compress/decompress points identically to o1js", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const privateKey = PrivateKey.random();
  //     const defaultPoint = privateKey.toPublicKey();
  //     const point = defaultPoint.toGroup();

  //     // Pass individual parameters
  //     const decompressed = await verifier.defaultToGroup(
  //       BigInt(defaultPoint.x.toString()),
  //       defaultPoint.isOdd.toBoolean()
  //     );

  //     expect(decompressed[0].toString()).to.equal(point.x.toString());
  //     expect(decompressed[1].toString()).to.equal(point.y.toString());
  //   });

  //   it("Should correctly convert between group formats", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const key = PrivateKey.random().toPublicKey();
  //     const point = {
  //       x: BigInt(key.x.toString()),
  //       y: BigInt(key.toGroup().y.toString()),
  //     };

  //     // Get back [x, isOdd]
  //     const [compressedX, isOdd] = await verifier.groupToDefault(
  //       point.x,
  //       point.y
  //     );

  //     const decompressed = await verifier.defaultToGroup(compressedX, isOdd);

  //     expect(decompressed[0].toString()).to.equal(point.x.toString());
  //     expect(decompressed[1].toString()).to.equal(point.y.toString());
  //   });
  // });

  // describe("String to Hash Conversion", function () {
  //   it("Should convert string to character array and hash correctly", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const testString = "test string";
  //     const [charValues, hashUint] = await verifier.fromStringToHash(
  //       testString
  //     );

  //     // Verify char array length matches DEFAULT_STRING_LENGTH
  //     expect(charValues.length).to.equal(128); // DEFAULT_STRING_LENGTH constant

  //     // Verify first few characters
  //     expect(Number(charValues[0])).to.equal(testString.charCodeAt(0)); // 't'
  //     expect(Number(charValues[1])).to.equal(testString.charCodeAt(1)); // 'e'

  //     // Verify padding with zeros
  //     for (let i = testString.length; i < 128; i++) {
  //       expect(charValues[i]).to.equal(0);
  //     }

  //     // Verify hash is non-zero
  //     expect(hashUint.toString()).to.not.equal("0");
  //   });

  //   it("Should revert on too long input", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     // Create string longer than DEFAULT_STRING_LENGTH
  //     const longString = "a".repeat(129);

  //     await expect(verifier.fromStringToHash(longString)).to.be.revertedWith(
  //       "CircuitString.fromString: input string exceeds max length!"
  //     );
  //   });

  //   it("Should handle empty string", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const [charValues, hashUint] = await verifier.fromStringToHash("");

  //     // Verify all zeros in char array
  //     expect(charValues.length).to.equal(128);
  //     expect(charValues.every((x) => x.toString() === "0")).to.be.true;

  //     // Even empty string should produce non-zero hash
  //     expect(hashUint.toString()).to.not.equal("0");
  //   });
  // });

  // describe("Public Key Validation", function () {
  //   it("Should validate points on the curve", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     // Generate valid point using o1js
  //     const privateKey = PrivateKey.random();
  //     const point = privateKey.toPublicKey().toGroup();

  //     const p = {
  //       x: BigInt(point.x.toString()),
  //       y: BigInt(point.y.toString()),
  //     };

  //     // Should be valid - exactly matches o1js check
  //     expect(await verifier.isValidPublicKey(p)).to.be.true;
  //   });

  //   it("Should reject points not on the curve", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     // Point with invalid y coordinate
  //     const invalidPoint = {
  //       x: 1n,
  //       y: 1n,
  //     };

  //     expect(await verifier.isValidPublicKey(invalidPoint)).to.be.false;
  //   });

  //   it("Should reject points >= FIELD_MODULUS", async function () {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     const invalidPoint = {
  //       x: FIELD_MODULUS, // Equal to modulus
  //       y: 0n,
  //     };

  //     expect(await verifier.isValidPublicKey(invalidPoint)).to.be.false;
  //   });
  // });

  // describe("Message Signature Verification", function () {
  //   async function deployAndSetupMessage() {
  //     const { verifier } = await loadFixture(deployVerifierFixture);

  //     // Setup mina-signer
  //     const client = new Client({ network: "mainnet" });

  //     // const keypair = client.genKeys();
  //     const keypair = {
  //       privateKey: "EKEEa7Kzjh5ttuSzyjWZF9NEtZrQpsC3taNwKfi8U1nud3MwKvNs",
  //       publicKey: "B62qj2vSpa1MEXNPZAkLdEzQdRS9iE8NhhRfpqLCAvW6QCPi8fxAYnM",
  //     };

  //     const message = "Test message for verification";

  //     // Get signed message
  //     const signedMessage = client.signMessage(message, keypair.privateKey);

  //     return { verifier, signedMessage, keypair, client, message };
  //   }

  //   it("Should verify message signature through all steps", async function () {
  //     const { verifier, signedMessage, client, message } = await loadFixture(
  //       deployAndSetupMessage
  //     );

  //     // const signatureObject = Signature.fromBase58(signedMessage.signature);
  //     const s = BigInt(signedMessage.signature.scalar);
  //     const r = BigInt(signedMessage.signature.field);

  //     const signer = PublicKey.fromBase58(signedMessage.publicKey);
  //     const signerFull = signer.toGroup();

  //     const result = client.verifyMessage({
  //       data: signedMessage.data,
  //       publicKey: signedMessage.publicKey,
  //       signature: signedMessage.signature,
  //     });

  //     const vmId = 0;

  //     let txn;
  //     txn = await verifier.step_0_VM_assignValues(
  //       { x: signerFull.x.toString(), y: signerFull.y.toString() },
  //       { r: r, s: s },
  //       message,
  //       true
  //     );
  //     await txn.wait();

  //     txn = await verifier.step_1_VM(vmId);
  //     await txn.wait();

  //     txn = await verifier.step_2_VM(vmId);
  //     await txn.wait();

  //     txn = await verifier.step_3_VM(vmId);
  //     await txn.wait();

  //     txn = await verifier.step_4_VM(vmId);
  //     await txn.wait();

  //     txn = await verifier.step_5_VM(vmId);
  //     await txn.wait();

  //     txn = await verifier.step_6_VM(vmId);
  //     await txn.wait();

  //     const finalObject = await verifier.getVMState(vmId);
  //     console.log(finalObject);
  //     expect(finalObject[12]).to.equal(result);
  //   });
  // });

  describe("Fields Signature Verification", function () {
    async function deployAndSetupFields() {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Setup mina-signer
      const client = new Client({ network: "mainnet" });

      // const keypair = client.genKeys();
      const keypair = {
        privateKey: "EKEEa7Kzjh5ttuSzyjWZF9NEtZrQpsC3taNwKfi8U1nud3MwKvNs",
        publicKey: "B62qj2vSpa1MEXNPZAkLdEzQdRS9iE8NhhRfpqLCAvW6QCPi8fxAYnM",
      };

      const fields = [
        123456989n,
        987654321n,
        23452344n,
        3465346n,
        21342321341534n,
      ];
      const signedFields = client.signFields(fields, keypair.privateKey);

      const altFields = [
        123456989n,
        987654321n,
        23452344n,
        3465346n,
        21342321341533n,
      ];
      const altSignedFields = client.signFields(altFields, keypair.privateKey);

      return { verifier, signedFields, altSignedFields, keypair, client };
    }

    it("Should verify signature through all steps in case valid.", async function () {
      const { verifier, signedFields, client } = await loadFixture(
        deployAndSetupFields
      );

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

      // Start verification steps
      const vfId = 0;

      let txn;
      txn = await verifier.step_0_VF_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        signedFields.data,
        false // testnet
      );
      await txn.wait();

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

      const finalObject = await verifier.getVFState(vfId);

      expect(finalObject[12]).to.equal(result);
    });
    it("Should return isValid=false in case invalid.", async function () {
      const { verifier, signedFields, altSignedFields, client } =
        await loadFixture(deployAndSetupFields);

      const signatureObject = Signature.fromBase58(altSignedFields.signature);
      const s = signatureObject.s.toBigInt();
      const r = signatureObject.r.toBigInt();

      const signer = PublicKey.fromBase58(signedFields.publicKey);
      const signerFull = signer.toGroup();

      const result = client.verifyFields({
        data: signedFields.data,
        signature: altSignedFields.signature,
        publicKey: signedFields.publicKey,
      });

      // Start verification steps
      const vfId = 0;

      let txn;
      txn = await verifier.step_0_VF_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        signedFields.data,
        false
      );

      await txn.wait();

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

      const finalObject = await verifier.getVFState(vfId);

      expect(finalObject[12]).to.equal(false);
      expect(finalObject[12]).to.equal(result);
    });
  });
});
