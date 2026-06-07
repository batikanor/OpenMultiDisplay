#!/usr/bin/env bash

openmultidisplay_codesign_identity() {
  if [ -n "${OPENMULTIDISPLAY_CODESIGN_IDENTITY:-}" ]; then
    printf '%s\n' "$OPENMULTIDISPLAY_CODESIGN_IDENTITY"
    return
  fi

  local identities preferred match
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  for preferred in \
    "Developer ID Application" \
    "Apple Development" \
    "OpenMultiDisplay Local Development" \
    "FluidVoice Local Development"; do
    match="$(
      printf '%s\n' "$identities" |
        sed -n "s/.*\"\(.*${preferred}.*\)\".*/\1/p" |
        head -1
    )"
    if [ -n "$match" ]; then
      printf '%s\n' "$match"
      return
    fi
  done

  printf '%s\n' "-"
}

openmultidisplay_sign_app() {
  local app_dir="$1"
  local entitlements="$2"
  local identity

  identity="$(openmultidisplay_codesign_identity)"
  if [ "$identity" = "-" ]; then
    echo "Code signing (ad-hoc; macOS privacy permission may reset after rebuilds)..."
  else
    echo "Code signing ($identity)..."
  fi

  codesign --force --deep --sign "$identity" --entitlements "$entitlements" "$app_dir"
}
