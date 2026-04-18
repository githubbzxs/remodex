#!/usr/bin/env node

const { randomUUID, generateKeyPairSync } = require("crypto");
const os = require("os");
const {
  readBridgeDeviceState,
  rememberTrustedPhone,
} = require("../src/secure-device-state");

const relayUrl = normalizeNonEmptyString(
  process.argv[2]
  || process.env.REMODEX_BOOTSTRAP_RELAY_URL
  || process.env.REMODEX_PACKAGE_DEFAULT_RELAY_URL
);

if (!relayUrl) {
  console.error("缺少 relay URL。可通过命令参数或 REMODEX_BOOTSTRAP_RELAY_URL 传入。");
  process.exit(1);
}

const bridgeState = readBridgeDeviceState();
if (!bridgeState) {
  console.error("未找到 bridge device state，请先启动 remodex bridge。");
  process.exit(1);
}

const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const privateJwk = privateKey.export({ format: "jwk" });
const publicJwk = publicKey.export({ format: "jwk" });
const phoneDeviceId = randomUUID().toUpperCase();
const phoneIdentityPrivateKey = base64UrlToBase64(privateJwk.d);
const phoneIdentityPublicKey = base64UrlToBase64(publicJwk.x);

rememberTrustedPhone(
  bridgeState,
  phoneDeviceId,
  phoneIdentityPublicKey,
  { persist: true }
);

const bootstrapConfig = {
  relayURL: relayUrl,
  macDeviceId: bridgeState.macDeviceId,
  macIdentityPublicKey: bridgeState.macIdentityPublicKey,
  macDisplayName: normalizeNonEmptyString(process.env.REMODEX_BOOTSTRAP_MAC_DISPLAY_NAME) || os.hostname(),
  phoneDeviceId,
  phoneIdentityPrivateKey,
  phoneIdentityPublicKey,
};

const serialized = JSON.stringify(bootstrapConfig);
const encoded = Buffer.from(serialized, "utf8").toString("base64");

process.stdout.write(`${encoded}\n`);

function normalizeNonEmptyString(value) {
  return typeof value === "string" && value.trim() ? value.trim() : "";
}

function base64UrlToBase64(value) {
  if (typeof value !== "string" || value.length === 0) {
    return "";
  }

  const padded = `${value}${"=".repeat((4 - (value.length % 4 || 4)) % 4)}`;
  return padded.replace(/-/g, "+").replace(/_/g, "/");
}
