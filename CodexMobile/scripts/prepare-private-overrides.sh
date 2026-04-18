#!/usr/bin/env bash

set -euo pipefail

# 根据本地环境变量生成被 .gitignore 忽略的 Xcode 私有覆盖配置。
# 这样 GitHub Actions 和本地构建都能在不提交敏感内容的前提下注入专用版参数。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OVERRIDES_PATH="${IOS_DIR}/BuildSupport/PrivateOverrides.xcconfig"

DEFAULT_RELAY_URL="${PHODEX_DEFAULT_RELAY_URL:-}"
DEDICATED_BOOTSTRAP_CONFIG_B64="${PHODEX_DEDICATED_BOOTSTRAP_CONFIG_B64:-}"

if [[ -z "${DEFAULT_RELAY_URL}" && -z "${DEDICATED_BOOTSTRAP_CONFIG_B64}" ]]; then
  exit 0
fi

mkdir -p "$(dirname "${OVERRIDES_PATH}")"

cat > "${OVERRIDES_PATH}" <<EOF
// 自动生成：请勿提交到仓库。
PHODEX_DEFAULT_RELAY_URL = "${DEFAULT_RELAY_URL}"
PHODEX_DEDICATED_BOOTSTRAP_CONFIG_B64 = "${DEDICATED_BOOTSTRAP_CONFIG_B64}"
EOF
