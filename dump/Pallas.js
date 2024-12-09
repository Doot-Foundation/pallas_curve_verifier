const {
  PrivateKey,
  Poseidon,
  Group,
  Field,
  CircuitString,
  PublicKey,
  Signature,
} = require("o1js");
const { Client } = require("mina-signer");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const signerClient = new Client({ network: "testnet" });

describe("Pallas Curve Verifier", function () {
  async function deployFixture() {
    const [deployer] = await ethers.getSigners();
    const Pallas = await ethers.getContractFactory("PallasSignatureVerifier", {
      gasLimit: 30000000,
    });
    const pallas = await Pallas.deploy();
    return { deployer, Pallas, pallas };
  }

  describe("Public Key Verification.", function () {
    it("Should verifiy if a Public Key (Pallas Curve Point) is valid.", async function () {
      const { pallas } = await loadFixture(deployFixture);

      const generatedPK = PrivateKey.random();
      const key = generatedPK.toPublicKey().toGroup();
      const key_x = BigInt(key.x.toString());
      const key_y = BigInt(key.y.toString());

      const point = {
        x: key_x,
        y: key_y,
      };

      const isValid = await pallas.isValidPublicKey(point);
      expect(isValid).to.be.true;
    });

    it("Should reject invalid public key point", async function () {
      const { pallas } = await loadFixture(deployFixture);

      const invalidPoint = {
        x: 1n,
        y: 1n,
      };

      const isValid = await pallas.isValidPublicKey(invalidPoint);
      expect(isValid).to.be.false;

      const tempPub = PrivateKey.random();
      const temp = tempPub.toPublicKey().toBase58();
      const temp_b = PublicKey.fromBase58(temp);
      console.log(tempPub.toPublicKey());
      console.log(tempPub.toPublicKey().toBase58());
      console.log(temp_b.x.toString(), temp_b.isOdd);
    });
  });

  // describe("Hash verification.", function () {
  //   it("The fromString() should match the original CircuitString.fromString() result", async function () {
  //     const { pallas } = await loadFixture(deployFixture);

  //     const jsResult = CircuitString.fromString("test string");
  //     const jsValues = jsResult.values.map((char) => char.value.toString());

  //     await pallas.fromString("test string");
  //     const solidityResult = await pallas.getTestLatestCharacter();
  //     const solidityValues = solidityResult.map((char) => String(char));

  //     for (let i = 0; i < CircuitString.DEFAULT_STRING_LENGTH; i++) {
  //       expect(solidityValues[i]).to.equal(jsValues[i].toString());
  //     }
  //   });

  //   it("Should match CircuitString -> Field translation.", async function () {
  //     const { pallas } = await loadFixture(deployFixture);

  //     const jsResult = CircuitString.fromString("test string");

  //     await pallas.fromString("test string");
  //     const solidityResult = await pallas.getTestLatestCharacter();
  //     const solidityValues = solidityResult.map((char) => String(char));
  //     const solidityHashInput = solidityValues.map((char) => [char]);

  //     const jsHash = jsResult.hash();
  //     await pallas.hashCircuitString(solidityHashInput);
  //     const solidityHash = await pallas.testLatestHash();

  //     expect(jsHash.toString()).to.be.equal(solidityHash);
  //   });
  // });

  // describe("Steps.", function () {
  //   it("Should get the same result calling step_1 as CircuitString -> Field.", async function () {
  //     const { pallas } = await loadFixture(deployFixture);
  //     const message = "test string";
  //     const expected = CircuitString.fromString(message).hash().toString();
  //     const verificationId = await pallas.verificationCounter();
  //     await pallas.step1_prepareMessage(message);
  //     const resultData = await pallas.signatureLifeCycle(verificationId);
  //     const result = resultData[2];
  //     expect(expected).to.be.equal(result);
  //   });
  // });
  // it("Should successfully generate the hash input.", async function () {
  //   const { pallas } = await loadFixture(deployFixture);

  //   const generatedPK = PrivateKey.random();
  //   const key = generatedPK.toPublicKey().toGroup();
  //   const key_x = BigInt(key.x.toString());
  //   const key_y = BigInt(key.y.toString());

  //   const point = {
  //     x: key_x,
  //     y: key_y,
  //   };

  //   const message = "test string";
  //   const signedMessage = signerClient.signMessage(
  //     message,
  //     generatedPK.toBase58()
  //   );

  //   const generatedSignature = Signature.from;
  //   console.log(signedMessage.signature);
  // });
});
