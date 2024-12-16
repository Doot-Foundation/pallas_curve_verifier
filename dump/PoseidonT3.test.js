const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { Field, CircuitString } = require("o1js");

const FIELD_MODULUS =
  45064998451067251948035796725861806592124573483999999999999993n;

describe("PoseidonT3", function () {
  async function deployPoseidonFixture() {
    const [deployer] = await ethers.getSigners();
    const PoseidonT3 = await ethers.getContractFactory("PoseidonT3");
    const poseidon = await PoseidonT3.deploy();
    return { poseidon, deployer };
  }

  describe("Basic Operations", function () {
    it("Should compute power7 correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      const x = 3n;

      let x2 = (x * x) % FIELD_MODULUS;
      let x3 = (x2 * x) % FIELD_MODULUS;
      let x6 = (x3 * x3) % FIELD_MODULUS;
      let jsResult = (x6 * x) % FIELD_MODULUS;
      jsResult = jsResult.toString();

      const result = await poseidon.power7(3);
      expect(result.toString()).to.equal(jsResult);
    });
  });

  describe("Hash Functions", function () {
    it("Should hash without prefix correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      const input = [Field(1), Field(2)].map((f) => BigInt(f.toString()));
      const result = await poseidon.poseidonHash(input);
      expect(result.toString()).to.not.equal("0");
    });

    it("Should hash with prefix correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      const prefix = "CodaSignature*******";
      const input = [Field(1), Field(2)].map((f) => BigInt(f.toString()));
      const result = await poseidon.poseidonHashWithPrefix(prefix, input);
      expect(result.toString()).to.not.equal("0");
    });
  });

  describe("Matrix Operations", function () {
    it("Should retrieve correct MDS matrix values", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      // Test getting first element of matrix
      const value00 = await poseidon.getMdsValue(0, 0);
      // Known value from constants.js
      expect(value00.toString()).to.equal(
        "12035446894107573964500871153637039653510326950134440362813193268448863222019"
      );

      // Test bounds
      await expect(poseidon.getMdsValue(3, 0)).to.be.revertedWith(
        "Invalid MDS indices"
      );
      await expect(poseidon.getMdsValue(0, 3)).to.be.revertedWith(
        "Invalid MDS indices"
      );
    });

    it("Should retrieve correct round constants", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      // Test first round constant
      const constant00 = await poseidon.getRoundConstant(0, 0);
      // Known value from constants.js
      expect(constant00.toString()).to.equal(
        "21155079691556475130150866428468322463125560312786319980770950159250751855431"
      );

      // Test bounds
      await expect(poseidon.getRoundConstant(55, 0)).to.be.revertedWith(
        "Invalid round constant indices"
      );
      await expect(poseidon.getRoundConstant(0, 3)).to.be.revertedWith(
        "Invalid round constant indices"
      );
    });

    it("Should perform MDS multiplication correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      // Simple test state
      const testState = [1n, 2n, 3n];
      const result = await poseidon.mdsMultiply(testState);

      // Result should be non-zero and have 3 elements
      expect(result.length).to.equal(3);
      expect(result.every((x) => x.toString() !== "0")).to.be.true;
    });
  });

  describe("Permutation and State", function () {
    it("Should initialize state correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      const state = await poseidon.initialState();
      expect(state.length).to.equal(3);
      expect(state.every((x) => x.toString() === "0")).to.be.true;
    });

    it("Should perform permutation correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      // Test with initial state
      const state = [1n, 2n, 3n];
      const result = await poseidon.poseidonPermutation(state);

      // Result should be different from input
      expect(result.length).to.equal(3);
      expect(result[0].toString()).to.not.equal("1");
      expect(result[1].toString()).to.not.equal("2");
      expect(result[2].toString()).to.not.equal("3");
    });

    it("Should update state correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      // Test with empty input
      const emptyState = [1n, 2n, 3n];
      const emptyResult = await poseidon.update(emptyState, []);
      expect(emptyResult.length).to.equal(3);

      // Test with actual input
      const state = [0n, 0n, 0n];
      const input = [1n, 2n]; // Rate is 2, so this is one block
      const result = await poseidon.update(state, input);
      expect(result.length).to.equal(3);
      expect(result.every((x) => x.toString() !== "0")).to.be.true;
    });

    it("Should handle multi-block update", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      // Test with input larger than rate
      const state = [0n, 0n, 0n];
      const input = [1n, 2n, 3n, 4n]; // Two blocks with rate=2
      const result = await poseidon.update(state, input);
      expect(result.length).to.equal(3);
      expect(result.every((x) => x.toString() !== "0")).to.be.true;
    });
  });

  describe("Field Conversion Operations", function () {
    it("Should convert string to fields correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      const testString = "Test123";
      const result = await poseidon.stringToFields(testString);

      const firstByte = result[0] & BigInt(0xff);
      expect(Number(firstByte)).to.equal(testString.charCodeAt(0));
    });

    it("Should convert bits to fields correctly", async function () {
      const { poseidon } = await loadFixture(deployPoseidonFixture);

      const testBits = Array(256).fill(false);
      testBits[0] = true;
      testBits[255] = true;
      const words = [1n | (1n << 255n)];

      const result = await poseidon.bitsToFields(words, 256n);
      expect(result[0].toString()).to.not.equal("0");
    });
  });
});
