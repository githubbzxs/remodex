#!/usr/bin/env bash

set -euo pipefail

# 用于本地或 CI 在无证书、无描述文件的前提下生成未签名 IPA。
# 产物目录默认固定在 CodexMobile/build/unsigned-ipa，便于 GitHub Actions 直接上传。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${IOS_DIR}/.." && pwd)"
ASSET_CATALOG_DIR="${IOS_DIR}/CodexMobile/Assets.xcassets"
APP_ICON_SET_NAME="${APP_ICON_SET_NAME:-Remodex}"
APP_ICON_SET_DIR="${ASSET_CATALOG_DIR}/${APP_ICON_SET_NAME}.appiconset"
APP_ICON_SOURCE_IMAGE="${APP_ICON_SOURCE_IMAGE:-${ASSET_CATALOG_DIR}/AppLogo.imageset/Phodex-iOS-Default-1024x1024@1x (1).png}"

PROJECT_PATH="${PROJECT_PATH:-${IOS_DIR}/CodexMobile.xcodeproj}"
SCHEME="${SCHEME:-CodexMobile}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${IOS_DIR}/build/derived-data-unsigned-ipa}"
OUTPUT_DIR="${OUTPUT_DIR:-${IOS_DIR}/build/unsigned-ipa}"
BUILD_LOG_PATH="${OUTPUT_DIR}/xcodebuild.log"
BUILD_INFO_PATH="${OUTPUT_DIR}/build-info.txt"
IOS_DEPLOYMENT_TARGET_OVERRIDE="${IOS_DEPLOYMENT_TARGET_OVERRIDE:-18.5}"

SHORT_SHA="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
IPA_BASENAME="${IPA_BASENAME:-${SCHEME}-unsigned-${CONFIGURATION}-${SHORT_SHA}}"
TEMP_APP_ICON_GENERATED=0

cleanup() {
  if [[ "${TEMP_APP_ICON_GENERATED}" == "1" ]]; then
    rm -rf "${APP_ICON_SET_DIR}"
  fi
}

trap cleanup EXIT

ensure_app_icon_set() {
  if [[ -d "${APP_ICON_SET_DIR}" ]]; then
    return
  fi

  if [[ ! -f "${APP_ICON_SOURCE_IMAGE}" ]]; then
    echo "缺少用于生成 App Icon 的源图片: ${APP_ICON_SOURCE_IMAGE}" >&2
    exit 1
  fi

  mkdir -p "${APP_ICON_SET_DIR}"

  # 仅为 iPhone 目标生成构建所需的最小图标集合，避免因为缺少 .appiconset 导致 actool 失败。
  while IFS='|' read -r filename pixel_size idiom size scale; do
    sips -z "${pixel_size}" "${pixel_size}" "${APP_ICON_SOURCE_IMAGE}" --out "${APP_ICON_SET_DIR}/${filename}" >/dev/null
  done <<'EOF'
Icon-App-20x20@2x.png|40|iphone|20x20|2x
Icon-App-20x20@3x.png|60|iphone|20x20|3x
Icon-App-29x29@2x.png|58|iphone|29x29|2x
Icon-App-29x29@3x.png|87|iphone|29x29|3x
Icon-App-40x40@2x.png|80|iphone|40x40|2x
Icon-App-40x40@3x.png|120|iphone|40x40|3x
Icon-App-60x60@2x.png|120|iphone|60x60|2x
Icon-App-60x60@3x.png|180|iphone|60x60|3x
Icon-App-1024x1024@1x.png|1024|ios-marketing|1024x1024|1x
EOF

  cat > "${APP_ICON_SET_DIR}/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "Icon-App-20x20@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "Icon-App-20x20@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "Icon-App-29x29@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-App-29x29@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "Icon-App-40x40@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-App-40x40@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "Icon-App-60x60@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "Icon-App-60x60@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "Icon-App-1024x1024@1x.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

  TEMP_APP_ICON_GENERATED=1
}

rm -rf "${DERIVED_DATA_PATH}" "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

ensure_app_icon_set

bash "${SCRIPT_DIR}/prepare-private-overrides.sh"

echo "开始构建未签名 IPA"
echo "PROJECT_PATH=${PROJECT_PATH}"
echo "SCHEME=${SCHEME}"
echo "CONFIGURATION=${CONFIGURATION}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"
echo "IOS_DEPLOYMENT_TARGET_OVERRIDE=${IOS_DEPLOYMENT_TARGET_OVERRIDE}"

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
  IPHONEOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET_OVERRIDE}" \
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
