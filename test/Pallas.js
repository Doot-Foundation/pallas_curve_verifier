const { PrivateKey, Signature, PublicKey } = require("o1js");
const { Client } = require("mina-signer");

const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("Pallas Curve Verifier", function () {
  this.timeout(50000);

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
    });
  });

  describe("Signature Verification", function () {
    it("Should verify if a Signature over a string is valid", async function () {
      const { pallas } = await loadFixture(deployFixture);

      const generatedPK = PrivateKey.random();
      const key = generatedPK.toPublicKey().toGroup();
      const key_x = BigInt(key.x.toString());
      const key_y = BigInt(key.y.toString());

      const message = "Hi";
      const client = new Client({ network: "testnet" });
      const signedMessage = client.signMessage(message, generatedPK.toBase58());

      // Get and log the exact scalar value
      const scalarValue = BigInt(signedMessage.signature.scalar);
      const scalarModulus = await pallas.SCALAR_MODULUS();

      console.log("\nDebug Values:");
      console.log("Original scalar (s):", scalarValue.toString());
      console.log("SCALAR_MODULUS:", scalarModulus.toString());
      console.log("Is s < SCALAR_MODULUS?", scalarValue < scalarModulus);

      // Ensure scalar is within proper range
      const signature = {
        r: BigInt(signedMessage.signature.field),
        s: scalarValue % scalarModulus,
      };

      const point = {
        x: key_x,
        y: key_y,
      };

      console.log("\nFinal Values:");
      console.log("Modified scalar (s):", signature.s.toString());
      console.log("Signature r:", signature.r.toString());
      console.log("Public Key x:", point.x.toString());
      console.log("Public Key y:", point.y.toString());

      const isValid = await pallas.verifyMessage(signature, point, message, {
        gasLimit: 30000000,
      });

      expect(isValid).to.be.true;
    });
  });
});
