const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { PrivateKey } = require("o1js");

const FIELD_MODULUS =
  28948022309329048855892746252171976963363056481941560715954676764349967630337n;

describe("PallasSignatureVerifier", function () {
  async function deployVerifierFixture() {
    const [deployer] = await ethers.getSigners();
    const PallasSignatureVerifier = await ethers.getContractFactory(
      "PallasSignatureVerifier"
    );
    const verifier = await PallasSignatureVerifier.deploy();
    return { verifier, deployer };
  }

  describe("Public Key Verification", function () {
    it("Should verify valid public key", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      const generatedPK = PrivateKey.random();
      const key = generatedPK.toPublicKey().toGroup();
      const point = {
        x: BigInt(key.x.toString()),
        y: BigInt(key.y.toString()),
      };

      const isValid = await verifier.isValidPublicKey(point);
      expect(isValid).to.be.true;
    });

    it("Should reject invalid public key point", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      const invalidPoint = { x: 1n, y: 1n };
      const isValid = await verifier.isValidPublicKey(invalidPoint);
      expect(isValid).to.be.false;
    });
  });

  describe("Point Conversion", function () {
    it("Should correctly convert between group formats", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      const key = PrivateKey.random().toPublicKey();
      const point = {
        x: BigInt(key.x.toString()),
        y: BigInt(key.toGroup().y.toString()),
      };

      const compressed = await verifier.groupToDefault(point);
      const decompressed = await verifier.defaultToGroup(compressed);

      expect(decompressed.x.toString()).to.equal(point.x.toString());
      expect(decompressed.y.toString()).to.equal(point.y.toString());
    });
  });

  describe("String to Hash Conversion", function () {
    it("Should convert string to character array and hash correctly", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      const testString = "test string";
      const [charValues, hashUint] = await verifier.fromStringToHash(
        testString
      );

      // Verify char array length matches DEFAULT_STRING_LENGTH
      expect(charValues.length).to.equal(128); // DEFAULT_STRING_LENGTH constant

      // Verify first few characters
      expect(Number(charValues[0])).to.equal(testString.charCodeAt(0)); // 't'
      expect(Number(charValues[1])).to.equal(testString.charCodeAt(1)); // 'e'

      // Verify padding with zeros
      for (let i = testString.length; i < 128; i++) {
        expect(charValues[i]).to.equal(0);
      }

      // Verify hash is non-zero
      expect(hashUint.toString()).to.not.equal("0");
    });

    it("Should revert on too long input", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Create string longer than DEFAULT_STRING_LENGTH
      const longString = "a".repeat(129);

      await expect(verifier.fromStringToHash(longString)).to.be.revertedWith(
        "CircuitString.fromString: input string exceeds max length!"
      );
    });

    it("Should handle empty string", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      const [charValues, hashUint] = await verifier.fromStringToHash("");

      // Verify all zeros in char array
      expect(charValues.length).to.equal(128);
      expect(charValues.every((x) => x.toString() === "0")).to.be.true;

      // Even empty string should produce non-zero hash
      expect(hashUint.toString()).to.not.equal("0");
    });
  });

  describe("Public Key Validation", function () {
    it("Should validate points on the curve", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Generate valid point using o1js
      const privateKey = PrivateKey.random();
      const point = privateKey.toPublicKey().toGroup();

      const p = {
        x: BigInt(point.x.toString()),
        y: BigInt(point.y.toString()),
      };

      // Should be valid - exactly matches o1js check
      expect(await verifier.isValidPublicKey(p)).to.be.true;
    });

    it("Should reject points not on the curve", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Point with invalid y coordinate
      const invalidPoint = {
        x: 1n,
        y: 1n,
      };

      expect(await verifier.isValidPublicKey(invalidPoint)).to.be.false;
    });

    it("Should reject points >= FIELD_MODULUS", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      const invalidPoint = {
        x: FIELD_MODULUS, // Equal to modulus
        y: 0n,
      };

      expect(await verifier.isValidPublicKey(invalidPoint)).to.be.false;
    });
  });

  describe("Group Point Conversion", function () {
    it("Should match o1js toGroup conversion", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Get point from o1js
      const privateKey = PrivateKey.random();
      const publicKey = privateKey.toPublicKey();
      const groupPoint = publicKey.toGroup();

      // Convert using our contract
      const compressed = {
        x: BigInt(publicKey.x.toString()),
        isOdd: publicKey.isOdd.toBoolean(),
      };

      const point = await verifier.defaultToGroup(compressed);

      // Should match o1js conversion
      expect(point.x.toString()).to.equal(groupPoint.x.toString());
      expect(point.y.toString()).to.equal(groupPoint.y.toString());
    });

    it("Should compress/decompress points identically to o1js", async function () {
      const { verifier } = await loadFixture(deployVerifierFixture);

      // Start with random point
      const privateKey = PrivateKey.random();
      const point = privateKey.toPublicKey().toGroup();

      const p = {
        x: BigInt(point.x.toString()),
        y: BigInt(point.y.toString()),
      };

      // Compress then decompress
      const compressed = await verifier.groupToDefault(p);
      const decompressed = await verifier.defaultToGroup(compressed);

      // Should match original
      expect(decompressed.x.toString()).to.equal(p.x.toString());
      expect(decompressed.y.toString()).to.equal(p.y.toString());
    });
  });
});
