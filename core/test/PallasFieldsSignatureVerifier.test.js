const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { Signature, PrivateKey, PublicKey } = require("o1js");
const { Client } = require("mina-signer");

function decodeABIEncodedDynamicArray(encodedData) {
  try {
    const data = encodedData.startsWith("0x")
      ? encodedData.slice(2)
      : encodedData;

    if (data.length < 128) {
      console.error("Encoded data too short");
      return { offset: 0, length: 0, elements: [] };
    }

    const offset = parseInt(data.slice(0, 64), 16);
    const length = parseInt(data.slice(64, 128), 16);

    if (length > 1000) {
      console.error("Suspiciously large array length:", length);
      return { offset, length, elements: [] };
    }

    const decodedArray = [];

    for (let i = 0; i < length; i++) {
      const elementStart = (offset + i * 32) * 2;

      if (elementStart + 64 > data.length) {
        console.error("Element out of bounds:", i);
        break;
      }

      const elementHex = data.slice(elementStart, elementStart + 64);

      decodedArray.push("0x" + elementHex);
    }

    return {
      offset,
      length,
      elements: decodedArray,
    };
  } catch (error) {
    console.error("Error in decodeABIEncodedDynamicArray:", error);
    return { offset: 0, length: 0, elements: [] };
  }
}

function decodeVFStateBytesCompressed(data) {
  if (data instanceof Uint8Array || Buffer.isBuffer(data)) {
    data =
      "0x" +
      Array.from(data)
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
  }

  if (!data.startsWith("0x")) {
    data = "0x" + data;
  }

  const state = {
    verifyType: 0,
    vfId: "0x" + "00".repeat(32),
    mainnet: false,
    isValid: false,
    publicKey: {
      x: "0x" + "00".repeat(32),
      y: "0x" + "00".repeat(32),
    },
    signature: {
      r: "0x" + "00".repeat(32),
      s: "0x" + "00".repeat(32),
    },
    messageHash: "0x" + "00".repeat(32),
    prefix: "",
    fields: [],
  };

  const dataBuffer = new Uint8Array(
    data
      .slice(2)
      .match(/.{1,2}/g)
      .map((byte) => parseInt(byte, 16))
  );

  state.verifyType = dataBuffer[0];
  console.log("verifyType:", state.verifyType);

  state.vfId =
    "0x" +
    Array.from(dataBuffer.slice(1, 33))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  console.log("vfId:", state.vfId);

  state.mainnet = dataBuffer[33] !== 0;
  console.log("mainnet:", state.mainnet);

  state.isValid = dataBuffer[34] !== 0;
  console.log("isValid:", state.isValid);

  state.publicKey.x =
    "0x" +
    Array.from(dataBuffer.slice(35, 67))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  console.log("publicKey.x:", state.publicKey.x);

  state.publicKey.y =
    "0x" +
    Array.from(dataBuffer.slice(67, 99))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  console.log("publicKey.y:", state.publicKey.y);

  state.signature.r =
    "0x" +
    Array.from(dataBuffer.slice(99, 131))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  console.log("signature.r:", state.signature.r);

  state.signature.s =
    "0x" +
    Array.from(dataBuffer.slice(131, 163))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  console.log("signature.s:", state.signature.s);

  state.messageHash =
    "0x" +
    Array.from(dataBuffer.slice(163, 195))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  console.log("messageHash:", state.messageHash);

  state.prefix = "CodaSignature*******";

  try {
    const fieldsData = data.slice(2 * 195 + 2);
    const decodedFields = decodeABIEncodedDynamicArray("0x" + fieldsData);
    state.fields = decodedFields.elements;

    console.log("fields array length:", state.fields.length);
  } catch (error) {
    console.error("Error decoding fields:", error);
    state.fields = [];
  }

  return state;
}

describe("PallasFieldsSignatureVerifier", function () {
  async function deployVerifierFixture() {
    const [deployer] = await ethers.getSigners();
    const PallasSignatureVerifier = await ethers.getContractFactory(
      "PallasFieldsSignatureVerifier"
    );
    const verifier = await PallasSignatureVerifier.deploy();
    return { verifier, deployer };
  }

  describe("Fields Signature Verification", function () {
    async function deployAndSetupFields() {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Setup mina-signer
      const client = new Client({ network: "testnet" });

      // const keypair = client.genKeys();
      const keypair = {
        privateKey: "EKEEa7Kzjh5ttuSzyjWZF9NEtZrQpsC3taNwKfi8U1nud3MwKvNs",
        publicKey: "B62qj2vSpa1MEXNPZAkLdEzQdRS9iE8NhhRfpqLCAvW6QCPi8fxAYnM",
      };

      const fields = [
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
      ];
      const signedFields = client.signFields(fields, keypair.privateKey);

      const altFields = [
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999990n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999990n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999999n,
        998899999999999999999999999999999999999999999999999990n,
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
      const vfId = 1;

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
      const bytesObject = await verifier.getVFStateBytesCompressed(vfId);
      // const decodedsol = await verifier.decodeVFStateBytesCompressed(
      //   bytesObject
      // );
      // console.log(decodedsol);
      const decodedjs = decodeVFStateBytesCompressed(bytesObject);
      console.log(decodedjs);

      expect(finalObject[2]).to.equal(result);
      expect(finalObject[2]).to.equal(true);
    });
    it("Should return isValid=false in case invalid.", async function () {
      const { verifier, signedFields, altSignedFields, client } =
        await loadFixture(deployAndSetupFields);

      /// 3 TEST CASES : signedFields is our original object.
      ///   1. DIFFERENT SIGNATURE
      ///   2. DIFFERENT DATA
      ///   3. DIFFERENT PUBLIC KEY

      /// DIFFERENT SIGNATURE -------------------------------------------------
      let signatureObject = Signature.fromBase58(altSignedFields.signature);
      let s = signatureObject.s.toBigInt();
      let r = signatureObject.r.toBigInt();

      let signer = PublicKey.fromBase58(signedFields.publicKey);
      let signerFull = signer.toGroup();

      let result = client.verifyFields({
        data: signedFields.data,
        signature: altSignedFields.signature,
        publicKey: signedFields.publicKey,
      });

      let vfId = 1;

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

      let finalObject = await verifier.getVFState(vfId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);

      /// DIFFERENT DATA -------------------------------------------------
      signatureObject = Signature.fromBase58(signedFields.signature);
      s = signatureObject.s.toBigInt();
      r = signatureObject.r.toBigInt();

      signer = PublicKey.fromBase58(signedFields.publicKey);
      signerFull = signer.toGroup();

      result = client.verifyFields({
        data: altSignedFields.data,
        signature: signedFields.signature,
        publicKey: signedFields.publicKey,
      });

      vfId = 2;

      txn;
      txn = await verifier.step_0_VF_assignValues(
        { x: signerFull.x.toString(), y: signerFull.y.toString() },
        { r: r, s: s },
        altSignedFields.data,
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

      finalObject = await verifier.getVFState(vfId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);

      /// DIFFERENT PUBLIC KEY -------------------------------------------------
      signatureObject = Signature.fromBase58(signedFields.signature);
      s = signatureObject.s.toBigInt();
      r = signatureObject.r.toBigInt();

      const randomPK = PrivateKey.random();
      const random = randomPK.toPublicKey();
      const randomFull = random.toGroup();

      result = client.verifyFields({
        data: signedFields.data,
        signature: signedFields.signature,
        publicKey: random.toBase58(),
      });

      vfId = 3;

      txn;
      txn = await verifier.step_0_VF_assignValues(
        { x: randomFull.x.toString(), y: randomFull.y.toString() },
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

      finalObject = await verifier.getVFState(vfId);

      expect(finalObject[2]).to.equal(false);
      expect(finalObject[2]).to.equal(result);
    });
  });
});
