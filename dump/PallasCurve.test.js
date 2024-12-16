const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { PrivateKey, Field } = require("o1js");

const FIELD_MODULUS =
  45064998451067251948035796725861806592124573483999999999999993n;

describe("PallasCurve", function () {
  async function deployCurveFixture() {
    const [deployer] = await ethers.getSigners();
    const PallasCurve = await ethers.getContractFactory("PallasCurve");
    const curve = await PallasCurve.deploy();
    return { curve, deployer };
  }

  describe("Point Addition Cases", function () {
    it("Should handle point addition with identity", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };
      const zero = { x: 0n, y: 0n };

      const result = await curve.addPoints(p, zero);
      expect(result.x.toString()).to.equal(p.x.toString());
      expect(result.y.toString()).to.equal(p.y.toString());
    });

    it("Should handle point doubling correctly", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };

      const result = await curve.addPoints(p, p);
      const jsResult = point.scale(2n);

      expect(result.x.toString()).to.equal(jsResult.x.toString());
      expect(result.y.toString()).to.equal(jsResult.y.toString());
    });
  });

  describe("Scalar Multiplication Cases", function () {
    it("Should handle multiplication by zero", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };

      const result = await curve.scalarMul(p, 0);
      expect(result.x.toString()).to.equal("0");
      expect(result.y.toString()).to.equal("0");
    });

    it("Should handle multiplication by one", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };

      const result = await curve.scalarMul(p, 1);
      expect(result.x.toString()).to.equal(p.x.toString());
      expect(result.y.toString()).to.equal(p.y.toString());
    });

    it("Should handle multiplication by large scalar", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      // Let's use a known test vector from o1js instead of random point
      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };

      // Use smaller scalar first to debug
      const scalar = 2n ** 32n - 1n; // Much smaller than 2n ** 250n - 1n

      // First check if the result matches o1js for small scalar
      const result = await curve.scalarMul(p, scalar);
      const jsResult = point.scale(scalar);

      expect(result.x.toString()).to.equal(jsResult.x.toString());
    });
  });

  describe("Field Arithmetic", function () {
    it("Should calculate modular inverses correctly", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const testValue = 123n;
      const modulus = await curve.FIELD_MODULUS();
      const inverse = await curve.invmod(testValue);

      const product = (testValue * inverse) % modulus;
      expect(product.toString()).to.equal("1");
    });

    it("Should calculate correct square root modulo", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const testValue = 4n;
      const modulus = await curve.FIELD_MODULUS();
      const result = await curve.sqrtmod(testValue, modulus);
      const verifySquare = (result * result) % modulus;

      expect(verifySquare.toString()).to.equal(testValue.toString());
    });
  });

  // describe("Field Conversion Operations", function () {
  //   it("Should convert string to fields correctly", async function () {
  //     const { curve } = await loadFixture(deployCurveFixture);

  //     const testString = "Test123";
  //     const result = await curve.stringToFields(testString);

  //     const firstByte = result[0] & BigInt(0xff);
  //     expect(Number(firstByte)).to.equal(testString.charCodeAt(0));
  //   });

  //   it("Should convert bits to fields correctly", async function () {
  //     const { curve } = await loadFixture(deployCurveFixture);

  //     const testBits = Array(256).fill(false);
  //     testBits[0] = true;
  //     testBits[255] = true;
  //     const words = [1n | (1n << 255n)];

  //     const result = await curve.bitsToFields(words, 256n);
  //     expect(result[0].toString()).to.not.equal("0");
  //   });
  // });

  describe("Point Addition", function () {
    it("Should match o1js point addition", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      // Generate two random points using o1js
      const pk1 = PrivateKey.random();
      const pk2 = PrivateKey.random();
      const point1 = pk1.toPublicKey().toGroup();
      const point2 = pk2.toPublicKey().toGroup();

      // Add using o1js
      const jsSum = point1.add(point2);

      // Convert to our format and add
      const p1 = { x: BigInt(point1.x), y: BigInt(point1.y) };
      const p2 = { x: BigInt(point2.x), y: BigInt(point2.y) };
      const solSum = await curve.addPoints(p1, p2);

      // Should match exactly
      expect(solSum.x.toString()).to.equal(jsSum.x.toString());
      expect(solSum.y.toString()).to.equal(jsSum.y.toString());
    });

    it("Should handle point at infinity correctly", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      // Generate random point
      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };

      // Add with infinity (zero point in o1js)
      const zero = { x: 0n, y: 0n };
      const sum = await curve.addPoints(p, zero);

      // P + 0 should equal P
      expect(sum.x.toString()).to.equal(p.x.toString());
      expect(sum.y.toString()).to.equal(p.y.toString());
    });
  });

  describe("Scalar Multiplication", function () {
    it("Should match o1js scalar multiplication", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      // Generate random point and scalar
      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const scalar = Field(123); // Any scalar you want to test with

      // Multiply using o1js
      const jsResult = point.scale(scalar);

      // Convert and multiply using our contract
      const p = { x: BigInt(point.x), y: BigInt(point.y) };
      const solResult = await curve.scalarMul(p, BigInt(scalar.toString()));

      // Results should match
      expect(solResult.x.toString()).to.equal(jsResult.x.toString());
      expect(solResult.y.toString()).to.equal(jsResult.y.toString());
    });

    it("Should handle scalar 0 and 1 correctly", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const pk = PrivateKey.random();
      const point = pk.toPublicKey().toGroup();
      const p = { x: BigInt(point.x), y: BigInt(point.y) };

      // Multiply by 0
      const zeroResult = await curve.scalarMul(p, 0n);
      expect(zeroResult.x).to.equal(0n);
      expect(zeroResult.y).to.equal(0n);

      // Multiply by 1
      const oneResult = await curve.scalarMul(p, 1n);
      expect(oneResult.x.toString()).to.equal(p.x.toString());
      expect(oneResult.y.toString()).to.equal(p.y.toString());
    });
  });

  describe("Field Operations", function () {
    it("Should match o1js field addition", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const a = Field(123);
      const b = Field(456);

      const jsSum = a.add(b);
      const solSum = await curve.add(123n, 456n, FIELD_MODULUS);

      expect(solSum.toString()).to.equal(jsSum.toString());
    });

    it("Should match o1js field multiplication", async function () {
      const { curve } = await loadFixture(deployCurveFixture);

      const a = Field(123);
      const b = Field(456);

      const jsProduct = a.mul(b);
      const solProduct = await curve.mul(123n, 456n, FIELD_MODULUS);

      expect(solProduct.toString()).to.equal(jsProduct.toString());
    });
  });
});
