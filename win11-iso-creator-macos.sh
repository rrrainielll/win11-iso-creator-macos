#!/bin/bash
set -euo pipefail

# Colors
nc='\033[0m'
red='\033[31m'
green='\033[32m'
yellow='\033[33m'

print_help() {
  echo ""
  echo "NAME"
  echo "    $(basename "${0}")"
  echo ""
  echo "SYNOPSIS"
  echo "    sudo ./$(basename "${0}") [<Windows 10 ISO path> <Windows 11 ISO path>]"
  echo ""
  echo "DESCRIPTION"
  echo "    Creates a Win11 ISO that looks like Win10 media for Boot Camp support software."
  echo "    - Copies all files from Win10 ISO except install.wim/install.esd"
  echo "    - Copies install.wim (or install.esd) from Win11 ISO into the new image"
  echo ""
  echo "NOTES"
  echo "    Works regardless of mounted volume names."
  echo ""
}

die() {
  echo -e "${red}ERROR:${nc} $*" >&2
  exit 1
}

need_root() {
  if [ "${EUID}" -ne 0 ]; then
    die "Please run with sudo."
  fi
}

# ---- Arg validation ----
if [ "${#}" -gt 2 ] || echo "$*" | grep -q -- "-help"; then
  print_help
  exit 0
fi

if [ "${#}" -eq 2 ]; then
  WIN10_ISO="$1"
  WIN11_ISO="$2"
elif [ "${#}" -eq 0 ]; then
  echo "Select Windows 10 ISO..."
  WIN10_ISO="$(osascript -e 'POSIX path of (choose file with prompt "Select Windows 10 ISO" of type {"iso"})' 2>/dev/null)" || die "Cancelled."
  echo "Selected: ${WIN10_ISO}"

  echo "Select Windows 11 ISO..."
  WIN11_ISO="$(osascript -e 'POSIX path of (choose file with prompt "Select Windows 11 ISO" of type {"iso"})' 2>/dev/null)" || die "Cancelled."
  echo "Selected: ${WIN11_ISO}"
else
  print_help
  die "Expected exactly 0 or 2 arguments."
fi

[ -n "${WIN10_ISO}" ] || die "Windows 10 ISO path must not be empty"
[ -n "${WIN11_ISO}" ] || die "Windows 11 ISO path must not be empty"

[ -f "${WIN10_ISO}" ] || die "Unable to find Windows 10 ISO at path: ${WIN10_ISO}"
[ -f "${WIN11_ISO}" ] || die "Unable to find Windows 11 ISO at path: ${WIN11_ISO}"

# Basic sanity: file sizes should not be zero
WIN10_SIZE=$(stat -f%z "${WIN10_ISO}" 2>/dev/null || echo 0)
WIN11_SIZE=$(stat -f%z "${WIN11_ISO}" 2>/dev/null || echo 0)
[ "${WIN10_SIZE}" -gt 1000000000 ] || echo -e "${yellow}WARNING:${nc} Win10 ISO looks small (${WIN10_SIZE} bytes). Make sure it's a real ISO."
[ "${WIN11_SIZE}" -gt 1000000000 ] || echo -e "${yellow}WARNING:${nc} Win11 ISO looks small (${WIN11_SIZE} bytes). Make sure it's a real ISO."

# ISO extension check (soft)
echo "${WIN10_ISO}" | grep -qiE '\.iso$' || echo -e "${yellow}WARNING:${nc} Win10 file does not end with .iso"
echo "${WIN11_ISO}" | grep -qiE '\.iso$' || echo -e "${yellow}WARNING:${nc} Win11 file does not end with .iso"

need_root

echo "STARTING PREPARE_INSTALLER"
echo ""
echo -e "Found Windows 10 ISO at path: ${green}${WIN10_ISO}${nc}"
echo -e "Found Windows 11 ISO at path: ${green}${WIN11_ISO}${nc}"
echo ""

# ---- Helpers ----
TMP_DMG="/tmp/Windows11.dmg"
OUT_CDR="/tmp/Windows11.cdr"
OUT_ISO="/tmp/Win11_BootCamp.iso"

DMG_MOUNT="/Volumes/Windows11"
WIN10_MOUNT=""
WIN11_MOUNT=""

cleanup() {
  set +e

  # Detach mounted ISOs if present
  if [ -n "${WIN11_MOUNT}" ] && mount | grep -q "${WIN11_MOUNT}"; then
    hdiutil detach "${WIN11_MOUNT}" -force >/dev/null 2>&1
  fi
  if [ -n "${WIN10_MOUNT}" ] && mount | grep -q "${WIN10_MOUNT}"; then
    hdiutil detach "${WIN10_MOUNT}" -force >/dev/null 2>&1
  fi

  # Detach DMG mount if present
  if mount | grep -q "${DMG_MOUNT}"; then
    hdiutil detach "${DMG_MOUNT}" -force >/dev/null 2>&1
  fi

  # Remove temp DMG
  rm -f "${TMP_DMG}" >/dev/null 2>&1
}
trap cleanup EXIT

attach_iso_get_mount() {
  local iso_path="$1"
  # Attach and extract the mountpoint from hdiutil output
  # Output format includes: /dev/diskX  Apple_HFS  /Volumes/NAME
  local mp
  mp="$(hdiutil attach -nobrowse -readonly "${iso_path}" 2>/dev/null | awk '/\/Volumes\//{print $NF; exit}')"
  [ -n "${mp}" ] || die "Failed to mount ISO: ${iso_path}"
  echo "${mp}"
}

find_install_image() {
  local mp="$1"
  if [ -f "${mp}/sources/install.wim" ]; then
    echo "${mp}/sources/install.wim"
    return 0
  fi
  if [ -f "${mp}/sources/install.esd" ]; then
    echo "${mp}/sources/install.esd"
    return 0
  fi
  return 1
}

# ---- Execute ----

# Create DMG
echo "Creating temporary DMG..."
hdiutil create -o "${TMP_DMG}" -size 7000m -volname Windows11 -fs UDF >/dev/null

# Mount DMG
echo "Mounting temporary DMG at ${DMG_MOUNT}..."
hdiutil attach "${TMP_DMG}" -noverify -nobrowse -mountpoint "${DMG_MOUNT}" >/dev/null

# Mount Win10 ISO
echo "Mounting Windows 10 ISO..."
WIN10_MOUNT="$(attach_iso_get_mount "${WIN10_ISO}")"
echo -e "Windows 10 mounted at: ${green}${WIN10_MOUNT}${nc}"

# Copy all files except install image from Win10 -> DMG
echo "Copying Win10 files (excluding install.wim/install.esd)..."
rsync -avh --progress \
  --exclude="sources/install.wim" \
  --exclude="sources/install.esd" \
  "${WIN10_MOUNT}/" "${DMG_MOUNT}/"

# Detach Win10 ISO
echo "Unmounting Windows 10 ISO..."
hdiutil detach "${WIN10_MOUNT}" -force >/dev/null
WIN10_MOUNT=""

# Mount Win11 ISO
echo "Mounting Windows 11 ISO..."
WIN11_MOUNT="$(attach_iso_get_mount "${WIN11_ISO}")"
echo -e "Windows 11 mounted at: ${green}${WIN11_MOUNT}${nc}"

# Copy install.wim or install.esd from Win11 -> DMG
echo "Locating Windows 11 install image (install.wim or install.esd)..."
INSTALL_IMG="$(find_install_image "${WIN11_MOUNT}")" || {
  echo "Listing ${WIN11_MOUNT}/sources for debugging:"
  ls -lah "${WIN11_MOUNT}/sources" || true
  die "Could not find install.wim or install.esd in ${WIN11_MOUNT}/sources"
}

echo -e "Using install image: ${green}${INSTALL_IMG}${nc}"
echo "Copying install image into DMG..."
sudo rsync -ah --progress "${INSTALL_IMG}" "${DMG_MOUNT}/sources/"

# Detach Win11 ISO
echo "Unmounting Windows 11 ISO..."
hdiutil detach "${WIN11_MOUNT}" -force >/dev/null
WIN11_MOUNT=""

# Detach DMG
echo "Unmounting temporary DMG..."
hdiutil detach "${DMG_MOUNT}" -force >/dev/null

# Convert DMG to ISO-like CDR then rename
echo "Converting DMG to ISO..."
rm -f "${OUT_CDR}" "${OUT_ISO}" >/dev/null 2>&1 || true
hdiutil convert "${TMP_DMG}" -format UDTO -o "${OUT_CDR}" >/dev/null

# hdiutil outputs Windows11.cdr (and sometimes .cdr.dmg style). Normalize:
if [ -f "${OUT_CDR}" ]; then
  mv -f "${OUT_CDR}" "${OUT_ISO}"
elif [ -f "${OUT_CDR}.cdr" ]; then
  mv -f "${OUT_CDR}.cdr" "${OUT_ISO}"
else
  # Find whatever hdiutil created
  FOUND="$(ls -1 "/tmp" | grep -E '^Windows11\.cdr' | head -n 1 || true)"
  [ -n "${FOUND}" ] || die "Could not find converted CDR in /tmp."
  mv -f "/tmp/${FOUND}" "${OUT_ISO}"
fi

echo ""
echo "Select where to save the final ISO..."
if DEST_ISO="$(osascript -e 'POSIX path of (choose file name with prompt "Save Windows 11 ISO as:" default name "Win11_BootCamp.iso" default location (path to desktop folder))' 2>/dev/null)"; then
  echo "Moving ISO to selected path..."
  mv -f "${OUT_ISO}" "${DEST_ISO}"
  echo -e "Windows 11 ISO saved at: ${green}${DEST_ISO}${nc}"
else
  echo "Selection cancelled. Moving to Desktop..."
  mv -f "${OUT_ISO}" "$HOME/Desktop/Win11_BootCamp.iso"
  echo -e "Windows 11 ISO saved at: ${green}$HOME/Desktop/Win11_BootCamp.iso${nc}"
fi

echo -e "${green}PREPARE_INSTALLER COMPLETED SUCCESSFULLY${nc}"
