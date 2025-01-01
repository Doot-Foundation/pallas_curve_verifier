function decodeABIEncodedDynamicArray(encodedData) {
  try {
    const data = encodedData.startsWith("0x")
      ? encodedData.slice(2)
      : encodedData;

    if (data.length < 128) {
      console.error("Encoded data too short");
      return { offset: 0, length: 0, elements: [] };
    }

    const offset = parseInt(data.slice(0, 64), 16);
    const length = parseInt(data.slice(64, 128), 16);

    if (length > 1000) {
      console.error("Suspiciously large array length:", length);
      return { offset, length, elements: [] };
    }

    const decodedArray = [];

    for (let i = 0; i < length; i++) {
      const elementStart = (offset + i * 32) * 2;

      if (elementStart + 64 > data.length) {
        console.error("Element out of bounds:", i);
        break;
      }

      const elementHex = data.slice(elementStart, elementStart + 64);

      decodedArray.push("0x" + elementHex);
    }

    return {
      offset,
      length,
      elements: decodedArray,
    };
  } catch (error) {
    console.error("Error in decodeABIEncodedDynamicArray:", error);
    return { offset: 0, length: 0, elements: [] };
  }
}

function decodeVFStateBytesCompressed(data) {
  if (data instanceof Uint8Array || Buffer.isBuffer(data)) {
    data =
      "0x" +
      Array.from(data)
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
  }

  if (!data.startsWith("0x")) {
    data = "0x" + data;
  }

  const state = {
    verifyType: 0,
    vfId: "0x" + "00".repeat(32),
    mainnet: false,
    isValid: false,
    publicKey: {
      x: "0x" + "00".repeat(32),
      y: "0x" + "00".repeat(32),
    },
    signature: {
      r: "0x" + "00".repeat(32),
      s: "0x" + "00".repeat(32),
    },
    messageHash: "0x" + "00".repeat(32),
    prefix: "",
    fields: [],
  };

  const dataBuffer = new Uint8Array(
    data
      .slice(2)
      .match(/.{1,2}/g)
      .map((byte) => parseInt(byte, 16))
  );

  state.verifyType = dataBuffer[0];

  state.vfId =
    "0x" +
    Array.from(dataBuffer.slice(1, 33))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.mainnet = dataBuffer[33] !== 0;

  state.isValid = dataBuffer[34] !== 0;

  state.publicKey.x =
    "0x" +
    Array.from(dataBuffer.slice(35, 67))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.publicKey.y =
    "0x" +
    Array.from(dataBuffer.slice(67, 99))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.signature.r =
    "0x" +
    Array.from(dataBuffer.slice(99, 131))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.signature.s =
    "0x" +
    Array.from(dataBuffer.slice(131, 163))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.messageHash =
    "0x" +
    Array.from(dataBuffer.slice(163, 195))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.prefix = "CodaSignature*******";

  try {
    const fieldsData = data.slice(2 * 195 + 2);
    const decodedFields = decodeABIEncodedDynamicArray("0x" + fieldsData);
    state.fields = decodedFields.elements;
  } catch (error) {
    console.error("Error decoding fields:", error);
    state.fields = [];
  }

  return state;
}
function decodeABIEncodedString(encodedData) {
  try {
    const data = encodedData.startsWith("0x")
      ? encodedData.slice(2)
      : encodedData;

    if (data.length < 64) {
      console.error("Encoded data too short for string");
      return "";
    }

    const offset = parseInt(data.slice(0, 64), 16);
    const length = parseInt(data.slice(64, 128), 16);

    if (length > 1000000) {
      console.error("Suspiciously large string length:", length);
      return "";
    }

    const stringHex = data.slice(128, 128 + length * 2);
    const stringBytes = new Uint8Array(
      stringHex.match(/.{1,2}/g).map((byte) => parseInt(byte, 16))
    );

    return new TextDecoder().decode(stringBytes);
  } catch (error) {
    console.error("Error in decodeABIEncodedString:", error);
    return "";
  }
}

function decodeVMStateBytesCompressed(data) {
  if (data instanceof Uint8Array || Buffer.isBuffer(data)) {
    data =
      "0x" +
      Array.from(data)
        .map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
  }

  if (!data.startsWith("0x")) {
    data = "0x" + data;
  }

  const state = {
    verifyType: 0,
    vmId: "0x" + "00".repeat(32),
    mainnet: false,
    isValid: false,
    publicKey: {
      x: "0x" + "00".repeat(32),
      y: "0x" + "00".repeat(32),
    },
    signature: {
      r: "0x" + "00".repeat(32),
      s: "0x" + "00".repeat(32),
    },
    messageHash: "0x" + "00".repeat(32),
    prefix: "",
    message: "",
  };

  const dataBuffer = new Uint8Array(
    data
      .slice(2)
      .match(/.{1,2}/g)
      .map((byte) => parseInt(byte, 16))
  );

  state.verifyType = dataBuffer[0];

  state.vmId =
    "0x" +
    Array.from(dataBuffer.slice(1, 33))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.mainnet = dataBuffer[33] !== 0;

  state.isValid = dataBuffer[34] !== 0;

  state.publicKey.x =
    "0x" +
    Array.from(dataBuffer.slice(35, 67))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.publicKey.y =
    "0x" +
    Array.from(dataBuffer.slice(67, 99))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.signature.r =
    "0x" +
    Array.from(dataBuffer.slice(99, 131))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.signature.s =
    "0x" +
    Array.from(dataBuffer.slice(131, 163))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.messageHash =
    "0x" +
    Array.from(dataBuffer.slice(163, 195))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

  state.prefix = state.mainnet
    ? "MinaSignatureMainnet"
    : "CodaSignature*******";

  try {
    const messageData = data.slice(2 * 195 + 2);
    state.message = decodeABIEncodedString("0x" + messageData);
  } catch (error) {
    console.error("Error decoding message:", error);
    state.message = "";
  }

  return state;
}
module.exports = {
  decodeVFStateBytesCompressed,
  decodeVMStateBytesCompressed,
};
