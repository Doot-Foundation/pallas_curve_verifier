import { expect } from "chai";
import { ethers } from "hardhat";

describe("LayerZero Cross-Chain Testing", function () {
  let mockLzEndpointL1;
  let mockLzEndpointL2;
  let l1Receiver;
  let l2Sender;
  let owner;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    // Deploy mock LayerZero endpoints
    const MockLZEndpoint = await ethers.getContractFactory("MockLZEndpoint");
    mockLzEndpointL1 = await MockLZEndpoint.deploy(1); // L1 chain ID
    mockLzEndpointL2 = await MockLZEndpoint.deploy(110); // Arbitrum chain ID

    // Deploy your contracts
    const L1Receiver = await ethers.getContractFactory("EthereumReceiver");
    const L2Sender = await ethers.getContractFactory("ArbitrumBridge");

    l2Sender = await L2Sender.deploy(mockLzEndpointL2.address);
    l1Receiver = await L1Receiver.deploy(
      l2Sender.address, // trusted remote
      110, // srcChainId (Arbitrum)
      mockLzEndpointL1.address
    );

    // Register destinations in mock endpoints
    await mockLzEndpointL1.registerDestination(
      l1Receiver.address,
      l2Sender.address
    );
    await mockLzEndpointL2.registerDestination(
      l2Sender.address,
      l1Receiver.address
    );
  });

  it("Should successfully send and receive a single field verification", async function () {
    const verification = {
      isValid: true,
      fields: [ethers.utils.formatBytes32String("test")],
      signature: {
        r: ethers.utils.formatBytes32String("r"),
        s: ethers.utils.formatBytes32String("s"),
      },
      publicKey: {
        x: ethers.utils.formatBytes32String("x"),
        y: ethers.utils.formatBytes32String("y"),
      },
    };

    // Send from L2 to L1
    await expect(
      l2Sender.sendSingleFieldsVerification(
        1, // L1 chain ID
        l1Receiver.address,
        verification,
        { value: ethers.utils.parseEther("0.1") } // Mock LZ fees
      )
    )
      .to.emit(l1Receiver, "FieldsVerificationReceived")
      .withArgs(
        verification.isValid,
        verification.fields,
        verification.signature,
        verification.publicKey
      );
  });
});
