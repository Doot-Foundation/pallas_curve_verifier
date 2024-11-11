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

      // Setup keys and signature
      const generatedPK = PrivateKey.random();
      const key = generatedPK.toPublicKey().toGroup();
      const key_x = BigInt(key.x.toString());
      const key_y = BigInt(key.y.toString());

      const message = "Hi";
      const client = new Client({ network: "testnet" });
      const signedMessage = client.signMessage(message, generatedPK.toBase58());
      const o1jsVerification = client.verifyMessage({
        data: message,
        signature: signedMessage.signature,
        publicKey: generatedPK.toPublicKey().toBase58(),
      });
      console.log("\no1js verification result:", o1jsVerification);

      // Add debug for o1js internal values if possible
      console.log("\nVerification components:");
      console.log("Public key:", key);
      console.log("Message:", message);
      console.log("Signature:", signedMessage.signature);

      // Handle scalar values
      const scalarValue = BigInt(signedMessage.signature.scalar);
      const scalarModulus = await pallas.SCALAR_MODULUS();

      console.log("\nDebug Values:");
      console.log("Original scalar (s):", scalarValue.toString());
      console.log("SCALAR_MODULUS:", scalarModulus.toString());
      console.log("Is s < SCALAR_MODULUS?", scalarValue < scalarModulus);

      // Prepare signature and point
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

      try {
        // Step 1: Message to fields
        let messageFields = await pallas.step1_prepareMessage(message);
        messageFields = Array.from(messageFields, (x) => BigInt(x.toString()));
        console.log("Step 1 complete: Message fields prepared");

        // Step 2: Prepare hash input
        let hashInput = await pallas.step2_prepareHashInput(
          messageFields,
          point,
          signature.r
        );
        hashInput = Array.from(hashInput, (x) => BigInt(x.toString()));
        console.log("Step 2 complete: Hash input prepared");

        // Step 3: Compute hash
        const hash = await pallas.step3_computeHash(hashInput);
        console.log("Step 3 complete: Hash computed", hash.toString());

        // Step 4: Compute hP
        let hP = await pallas.step4_computeHP(point, hash);
        hP = { x: BigInt(hP.x.toString()), y: BigInt(hP.y.toString()) };
        console.log("Step 4 complete: hP computed");

        // Step 5: Negate hP
        let negHp = await pallas.step5_negatePoint(hP);
        negHp = {
          x: BigInt(negHp.x.toString()),
          y: BigInt(negHp.y.toString()),
        };
        console.log("Step 5 complete: Point negated");

        // Step 6: Compute sG
        let sG = await pallas.step6_computeSG(signature.s);
        sG = { x: BigInt(sG.x.toString()), y: BigInt(sG.y.toString()) };
        console.log("Step 6 complete: sG computed");

        // Step 7: Final addition
        let finalR = await pallas.step7_finalAddition(sG, negHp);
        finalR = {
          x: BigInt(finalR.x.toString()),
          y: BigInt(finalR.y.toString()),
        };
        console.log("Step 7 complete: Final point computed");

        console.log("\nFinal verification values:");
        console.log("finalR.x:", finalR.x.toString());
        console.log("finalR.y:", finalR.y.toString());
        console.log("signature.r:", signature.r.toString());
        console.log("Is y even?", finalR.y % 2n === 0n);

        // Step 8: Verify
        const isValid = await pallas.step8_verify(finalR, signature.r);
        console.log("Step 8 complete: Verification result:", isValid);
        console.log("Verification conditions:");
        console.log("x coordinates match?", finalR.x === signature.r);
        console.log("y coordinate is even?", finalR.y % 2n === 0n);

        expect(isValid).to.equal(o1jsVerification);
      } catch (error) {
        console.error("Error:", error);
        throw error;
      }
    });
  });
});
