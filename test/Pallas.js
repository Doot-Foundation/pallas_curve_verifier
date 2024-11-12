const { PrivateKey, Poseidon, Group, Field } = require("o1js");
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

      const scalarValue = BigInt(signedMessage.signature.scalar);
      const scalarModulus = await pallas.SCALAR_MODULUS();

      console.log("\nDebug Values:");
      console.log("Original scalar (s):", scalarValue.toString());
      console.log("SCALAR_MODULUS:", scalarModulus.toString());
      console.log("Is s < SCALAR_MODULUS?", scalarValue < scalarModulus);

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

      console.log("\no1js intermediate values:");
      const publicKeyPoint = { x: key_x, y: key_y };
      const r = BigInt(signedMessage.signature.field);
      const s = scalarValue % scalarModulus;

      // Create field elements
      const messageField = Field(26952); // "Hi"
      const xField = Field(key_x);
      const yField = Field(key_y);
      const rField = Field(r);

      // Use Poseidon hash
      const hash = Poseidon.hashWithPrefix("CodaSignature*******", [
        messageField,
        xField,
        yField,
        rField,
      ]);
      console.log("o1js hash:", hash.toString());

      // Create points using Group
      const P = Group.from({ x: key_x, y: key_y });
      const G = Group.generator; // Base point

      // Compute h*P
      const hP = Group.scale(P, hash);
      console.log("o1js hP - x:", hP.x.toString());
      console.log("o1js hP - y:", hP.y.toString());

      // Compute s*G
      const sG = Group.scale(G, s);
      console.log("o1js sG - x:", sG.x.toString());
      console.log("o1js sG - y:", sG.y.toString());

      // Compute final point R = sG - hP
      const neghP = Group.negate(hP);
      const R = Group.add(sG, neghP);
      console.log("o1js final R - x:", R.x.toString());
      console.log("o1js final R - y:", R.y.toString());
      console.log(
        "o1js R.x === signature.r:",
        Field(R.x).toString() === signature.r.toString()
      );
      console.log("o1js R.y is even:", BigInt(R.y.toString()) % 2n === 0n);

      try {
        // Step 1: Prepare message and get verification ID
        const step1Tx = await pallas.step1_prepareMessage(message);
        await step1Tx.wait();
        const verificationId = await pallas.verificationCounter();

        const step2Tx = await pallas.step2_prepareHashInput(
          verificationId,
          point,
          signature.r
        );
        await step2Tx.wait();

        const step3Tx = await pallas.step3_computeHash(verificationId);
        await step3Tx.wait();

        const step4Tx = await pallas.step4_computeHP(verificationId, point);
        await step4Tx.wait();

        const step5Tx = await pallas.step5_negatePoint(verificationId);
        await step5Tx.wait();

        const step6Tx = await pallas.step6_computeSG(
          verificationId,
          signature.s
        );
        await step6Tx.wait();

        const step7Tx = await pallas.step7_finalAddition(verificationId);
        await step7Tx.wait();

        const isValid = await pallas.step8_verify(verificationId, signature.r);
        expect(isValid).to.be.true;
      } catch (error) {
        console.error("Detailed error:", error);
        throw error;
      }
    });
  });
});
