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

      expect(finalObject[2]).to.equal(result);
      expect(finalObject[2]).to.equal(true);
    });
    // it("Should return isValid=false in case invalid.", async function () {
    //   const { verifier, signedFields, altSignedFields, client } =
    //     await loadFixture(deployAndSetupFields);

    //   /// 3 TEST CASES : signedFields is our original object.
    //   ///   1. DIFFERENT SIGNATURE
    //   ///   2. DIFFERENT DATA
    //   ///   3. DIFFERENT PUBLIC KEY

    //   /// DIFFERENT SIGNATURE -------------------------------------------------
    //   let signatureObject = Signature.fromBase58(altSignedFields.signature);
    //   let s = signatureObject.s.toBigInt();
    //   let r = signatureObject.r.toBigInt();

    //   let signer = PublicKey.fromBase58(signedFields.publicKey);
    //   let signerFull = signer.toGroup();

    //   let result = client.verifyFields({
    //     data: signedFields.data,
    //     signature: altSignedFields.signature,
    //     publicKey: signedFields.publicKey,
    //   });

    //   let vfId = 0;

    //   let txn;
    //   txn = await verifier.step_0_VF_assignValues(
    //     { x: signerFull.x.toString(), y: signerFull.y.toString() },
    //     { r: r, s: s },
    //     signedFields.data,
    //     false
    //   );

    //   await txn.wait();

    //   txn = await verifier.step_1_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_2_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_3_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_4_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_5_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_6_VF(vfId);
    //   await txn.wait();

    //   let finalObject = await verifier.getVFState(vfId);

    //   expect(finalObject[2]).to.equal(false);
    //   expect(finalObject[2]).to.equal(result);

    //   /// DIFFERENT DATA -------------------------------------------------
    //   signatureObject = Signature.fromBase58(signedFields.signature);
    //   s = signatureObject.s.toBigInt();
    //   r = signatureObject.r.toBigInt();

    //   signer = PublicKey.fromBase58(signedFields.publicKey);
    //   signerFull = signer.toGroup();

    //   result = client.verifyFields({
    //     data: altSignedFields.data,
    //     signature: signedFields.signature,
    //     publicKey: signedFields.publicKey,
    //   });

    //   vfId = 1;

    //   txn;
    //   txn = await verifier.step_0_VF_assignValues(
    //     { x: signerFull.x.toString(), y: signerFull.y.toString() },
    //     { r: r, s: s },
    //     altSignedFields.data,
    //     false
    //   );

    //   await txn.wait();

    //   txn = await verifier.step_1_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_2_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_3_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_4_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_5_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_6_VF(vfId);
    //   await txn.wait();

    //   finalObject = await verifier.getVFState(vfId);

    //   expect(finalObject[2]).to.equal(false);
    //   expect(finalObject[2]).to.equal(result);

    //   /// DIFFERENT PUBLIC KEY -------------------------------------------------
    //   signatureObject = Signature.fromBase58(signedFields.signature);
    //   s = signatureObject.s.toBigInt();
    //   r = signatureObject.r.toBigInt();

    //   const randomPK = PrivateKey.random();
    //   const random = randomPK.toPublicKey();
    //   const randomFull = random.toGroup();

    //   result = client.verifyFields({
    //     data: signedFields.data,
    //     signature: signedFields.signature,
    //     publicKey: random.toBase58(),
    //   });

    //   vfId = 2;

    //   txn;
    //   txn = await verifier.step_0_VF_assignValues(
    //     { x: randomFull.x.toString(), y: randomFull.y.toString() },
    //     { r: r, s: s },
    //     signedFields.data,
    //     false
    //   );

    //   await txn.wait();

    //   txn = await verifier.step_1_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_2_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_3_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_4_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_5_VF(vfId);
    //   await txn.wait();

    //   txn = await verifier.step_6_VF(vfId);
    //   await txn.wait();

    //   finalObject = await verifier.getVFState(vfId);

    //   expect(finalObject[2]).to.equal(false);
    //   expect(finalObject[2]).to.equal(result);
    // });
  });
});
