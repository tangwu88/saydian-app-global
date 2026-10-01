#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

case "${SAIDIAN_PRODUCTION_RELEASE:-}" in
  ""|false) production_release=false ;;
  true) production_release=true ;;
  *)
    echo "error: SAIDIAN_PRODUCTION_RELEASE must be true, false, or unset." >&2
    exit 1
    ;;
esac

case "${SAIDIAN_ALLOW_QA_RELEASE:-}" in
  ""|false) qa_release=false ;;
  true) qa_release=true ;;
  *)
    echo "error: SAIDIAN_ALLOW_QA_RELEASE must be true, false, or unset." >&2
    exit 1
    ;;
esac

if [ "$production_release" = "$qa_release" ]; then
  echo "error: Release builds require exactly one explicit Production or QA mode." >&2
  exit 1
fi

if [ "$qa_release" = "true" ]; then
  echo "warning: Building an explicitly non-production QA Release."
  exit 0
fi

if [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "cn.saydian.app.global" ]; then
  echo "error: Production iOS Release requires PRODUCT_BUNDLE_IDENTIFIER=cn.saydian.app.global." >&2
  exit 1
fi

if [ "${TARGETED_DEVICE_FAMILY:-}" != "1" ]; then
  echo "error: Production iOS Release must target iPhone only." >&2
  exit 1
fi

if [ "${INFOPLIST_FILE:-}" != "Runner/Info-AppStore.plist" ] || \
   [ "${CODE_SIGN_ENTITLEMENTS:-}" != "Runner/RunnerAppStore.entitlements" ]; then
  echo "error: Production iOS Release requires the payment- and push-free App Store plist and entitlements." >&2
  exit 1
fi

if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
  echo "error: Production iOS Release cannot disable code signing." >&2
  exit 1
fi

require_value() {
  if [ -z "$2" ]; then
    echo "error: Production iOS Release requires $1." >&2
    exit 1
  fi
}

require_value SAIDIAN_DEVELOPMENT_TEAM "${SAIDIAN_DEVELOPMENT_TEAM:-}"
require_value SAIDIAN_CODE_SIGN_IDENTITY "${SAIDIAN_CODE_SIGN_IDENTITY:-}"
require_value SAIDIAN_PROVISIONING_PROFILE_SPECIFIER \
  "${SAIDIAN_PROVISIONING_PROFILE_SPECIFIER:-}"
case "${SAYDIAN_API_BASE_URL:-}" in
  https://app.saydian.cn|https://app.saydian.cn/) ;;
  *)
    echo "error: Production iOS Release requires the approved global API origin." >&2
    exit 1
    ;;
esac

if [ -n "${JPUSH_APP_KEY:-}" ]; then
  echo "error: International App Store MVP must not activate unconfigured JPush." >&2
  exit 1
fi

case "${SAYDIAN_UPDATE_MANIFEST_URL:-}" in
  ""|https://app.saydian.cn/global/*) ;;
  *)
    echo "error: Optional update manifest must remain under the global service." >&2
    exit 1
    ;;
esac
