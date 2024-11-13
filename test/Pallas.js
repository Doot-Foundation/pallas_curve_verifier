const { PrivateKey, Poseidon, Group, Field, CircuitString } = require("o1js");
const { Client } = require("mina-signer");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

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
    });
  });

  describe("Hash Verification", function () {
    it("Should match o1js hash computation exactly", async function () {
      const { pallas } = await loadFixture(deployFixture);

      // o1js computation
      const prefix = "CodaSignature*******";
      const message = "test"; // Using a simple test message

      // O1js side
      const messageCircuitString = CircuitString.fromString("test");
      const messageField = messageCircuitString.hash();
      console.log("\nO1js computation:");
      console.log("Message as field:", messageField.toString());
      const o1jsPrefix = CircuitString.fromString(prefix).hash();
      console.log("Prefix as field:", o1jsPrefix.toString());

      const o1jsHash = Poseidon.hashWithPrefix(prefix, [messageField]);
      console.log("o1js final hash:", o1jsHash.toString());

      // Solidity side
      console.log("\nSolidity computation:");
      const step1 = await pallas.step1_prepareMessage(message);
      const verificationId = await pallas.verificationCounter();

      // Get message field
      const state = await pallas.getVerificationState(verificationId);
      console.log("Message as field:", state.messageFields[0].toString());

      // Get intermediate values
      const point = { x: BigInt(0), y: BigInt(0) };
      await pallas.step2_prepareHashInput(verificationId, point, BigInt(0));

      // Get hash input array
      const state2 = await pallas.getVerificationState(verificationId);
      console.log(
        "Hash input array:",
        state2.hashInput.map((x) => x.toString())
      );

      await pallas.step3_computeHash(verificationId);
      // console.log("Solidity final hash:", hashResult);
      const updatedState = await pallas.getVerificationState(verificationId);
      console.log(updatedState.hash);

      expect(updatedState.hash).to.equal(o1jsHash.toString());
    });

    it("Should match o1js hash with single field element", async function () {
      const { pallas } = await loadFixture(deployFixture);

      const testField = Field(123);
      const prefix = "CodaSignature*******";
      const o1jsHash = Poseidon.hashWithPrefix(prefix, [testField]);

      // Convert for Solidity input
      const step1 = await pallas.step1_prepareMessage("123");
      const verificationId = await pallas.verificationCounter();
      const point = { x: BigInt(0), y: BigInt(0) };
      const step2 = await pallas.step2_prepareHashInput(
        verificationId,
        point,
        BigInt(0)
      );
      const hashResult = await pallas.step3_computeHash(verificationId);

      const solidityHash = await pallas.getVerificationState(verificationId);
      expect(solidityHash.hash.toString()).to.equal(o1jsHash.toString());
    });
  });

  describe("Signature Verification", function () {
    it("Should verify if a Signature over a message is valid", async function () {
      const { pallas } = await loadFixture(deployFixture);

      // Generate random keypair
      const generatedPK = PrivateKey.random();
      const key = generatedPK.toPublicKey().toGroup();
      const key_x = key.x.toBigInt(); // Using toBigInt() instead of toString()
      const key_y = key.y.toBigInt();

      const message = "Hi";
      const client = new Client({ network: "testnet" });
      const signedMessage = client.signMessage(message, generatedPK.toBase58());

      const SCALAR_MODULUS = await pallas.SCALAR_MODULUS();

      const point = { x: key_x, y: key_y };
      const r = BigInt(signedMessage.signature.field);
      const s = BigInt(signedMessage.signature.scalar) % SCALAR_MODULUS; // Make sure s is reduced

      // Create fields for hash computation
      const messageField = Field(26952); // "Hi" converted
      const xField = Field.fromBigInt(key_x);
      const yField = Field.fromBigInt(key_y);
      const rField = Field.fromBigInt(r);

      // Compute o1js hash
      const hash = Poseidon.hashWithPrefix("CodaSignature*******", [
        messageField,
        xField,
        yField,
        rField,
      ]);

      try {
        // Step 1: Message preparation
        const step1Tx = await pallas.step1_prepareMessage(message);
        await step1Tx.wait();
        const verificationId = await pallas.verificationCounter();

        // Step 2: Hash input preparation
        const step2Tx = await pallas.step2_prepareHashInput(
          verificationId,
          point,
          r
        );
        await step2Tx.wait();

        // Step 3: Hash computation
        const step3Tx = await pallas.step3_computeHash(verificationId);
        await step3Tx.wait();

        // Compare hash
        const solidityHash = await pallas.getVerificationState(verificationId);
        expect(solidityHash.hash.toString()).to.equal(hash.toString());

        // Complete verification steps
        await pallas.step4_computeHP(verificationId, point);
        await pallas.step5_negatePoint(verificationId);
        await pallas.step6_computeSG(verificationId, s);
        await pallas.step7_finalAddition(verificationId);

        // Final verification
        const isValid = await pallas.step8_verify(verificationId, r);
        expect(isValid).to.be.true;
      } catch (error) {
        console.error("Detailed error:", error);
        throw error;
      }
    });

    it("Should reject invalid signatures", async function () {
      const { pallas } = await loadFixture(deployFixture);

      const generatedPK = PrivateKey.random();
      const key = generatedPK.toPublicKey().toGroup();
      const point = {
        x: key.x.toBigInt(),
        y: key.y.toBigInt(),
      };

      const message = "Hi";
      const client = new Client({ network: "testnet" });
      const signedMessage = client.signMessage(message, generatedPK.toBase58());

      // Modify signature to make it invalid
      const invalidR = BigInt(signedMessage.signature.field) + 1n;

      const step1Tx = await pallas.step1_prepareMessage(message);
      await step1Tx.wait();
      const verificationId = await pallas.verificationCounter();

      await pallas.step2_prepareHashInput(verificationId, point, invalidR);
      await pallas.step3_computeHash(verificationId);
      await pallas.step4_computeHP(verificationId, point);
      await pallas.step5_negatePoint(verificationId);
      await pallas.step6_computeSG(
        verificationId,
        BigInt(signedMessage.signature.scalar)
      );
      await pallas.step7_finalAddition(verificationId);

      const isValid = await pallas.step8_verify(verificationId, invalidR);
      expect(isValid).to.be.false;
    });
  });
});
