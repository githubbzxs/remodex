#!/usr/bin/env bash

set -euo pipefail

# 用于本地或 CI 在无证书、无描述文件的前提下生成未签名 IPA。
# 产物目录默认固定在 CodexMobile/build/unsigned-ipa，便于 GitHub Actions 直接上传。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${IOS_DIR}/.." && pwd)"

PROJECT_PATH="${PROJECT_PATH:-${IOS_DIR}/CodexMobile.xcodeproj}"
SCHEME="${SCHEME:-CodexMobile}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${IOS_DIR}/build/derived-data-unsigned-ipa}"
OUTPUT_DIR="${OUTPUT_DIR:-${IOS_DIR}/build/unsigned-ipa}"
BUILD_LOG_PATH="${OUTPUT_DIR}/xcodebuild.log"
BUILD_INFO_PATH="${OUTPUT_DIR}/build-info.txt"

SHORT_SHA="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
IPA_BASENAME="${IPA_BASENAME:-${SCHEME}-unsigned-${CONFIGURATION}-${SHORT_SHA}}"

rm -rf "${DERIVED_DATA_PATH}" "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo "开始构建未签名 IPA"
echo "PROJECT_PATH=${PROJECT_PATH}"
echo "SCHEME=${SCHEME}"
echo "CONFIGURATION=${CONFIGURATION}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  clean build | tee "${BUILD_LOG_PATH}"

APP_PATH="$(find "${DERIVED_DATA_PATH}/Build/Products" -maxdepth 2 -type d -path "*${CONFIGURATION}-iphoneos/*.app" | sort | head -n 1)"

if [[ -z "${APP_PATH}" ]]; then
  echo "未找到已构建的 .app 产物" >&2
  exit 1
fi

APP_BUNDLE_NAME="$(basename "${APP_PATH}")"
APP_OUTPUT_PATH="${OUTPUT_DIR}/${APP_BUNDLE_NAME}"
PACKAGE_ROOT="${OUTPUT_DIR}/package"
IPA_PATH="${OUTPUT_DIR}/${IPA_BASENAME}.ipa"

ditto "${APP_PATH}" "${APP_OUTPUT_PATH}"
mkdir -p "${PACKAGE_ROOT}/Payload"
ditto "${APP_PATH}" "${PACKAGE_ROOT}/Payload/${APP_BUNDLE_NAME}"

(
  cd "${PACKAGE_ROOT}"
  ditto -c -k --sequesterRsrc --keepParent Payload "${IPA_PATH}"
)

DSYM_PATH="$(find "${DERIVED_DATA_PATH}/Build/Products" -maxdepth 2 -type d -path "*${CONFIGURATION}-iphoneos/*.dSYM" | sort | head -n 1 || true)"
if [[ -n "${DSYM_PATH}" ]]; then
  ditto "${DSYM_PATH}" "${OUTPUT_DIR}/$(basename "${DSYM_PATH}")"
fi

rm -rf "${PACKAGE_ROOT}"

{
  echo "scheme=${SCHEME}"
  echo "configuration=${CONFIGURATION}"
  echo "git_sha=${SHORT_SHA}"
  echo "ipa_path=${IPA_PATH}"
  echo "app_path=${APP_OUTPUT_PATH}"
  if [[ -n "${DSYM_PATH}" ]]; then
    echo "dsym_path=${OUTPUT_DIR}/$(basename "${DSYM_PATH}")"
  fi
  echo "built_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "${BUILD_INFO_PATH}"

echo "未签名 IPA 已生成: ${IPA_PATH}"
