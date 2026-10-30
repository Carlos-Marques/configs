# KeePassXC 2.8.0, ahead of nixpkgs (still 2.7.12 on 2026-10-30), for its
# Polkit Quick Unlock: after the first unlock of a session the fingerprint
# reader unlocks the database, like Touch ID on the Mac. 2.8.0 also carries
# browser-integration security fixes 2.7.12 lacks (CHANGELOG.md).
#
# Follows nixpkgs' pkgs/by-name/ke/keepassxc/package.nix, ported to Qt6 and
# 2.8's KPXC_FEATURE_* options. Linux only. Replace with pkgs.keepassxc once
# nixpkgs has 2.8.
{
  lib,
  stdenv,
  fetchFromGitHub,
  path,

  asciidoctor,
  cmake,
  pkg-config,
  qt6,
  wrapGAppsHook3,

  botan3,
  keyutils,
  libusb1,
  libx11,
  libxi,
  libxkbcommon,
  libxtst,
  minizip,
  pcsclite,
  qrencode,
  readline,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "keepassxc";
  version = "2.8.0";

  src = fetchFromGitHub {
    owner = "keepassxreboot";
    repo = "keepassxc";
    tag = finalAttrs.version;
    hash = "sha256-821zL+xnCsHU8VvxsJh2a2LRGstSIq3tWQbWBk8g4hc=";
  };

  # As in nixpkgs: upstream builds against Xcode's PCSC, whose types don't
  # match pcsclite's.
  postPatch = ''
    substituteInPlace src/keys/drivers/YubiKeyInterfacePCSC.cpp \
      --replace-fail "typedef uint32_t RETVAL;" "typedef int32_t RETVAL;"
  '';

  cmakeFlags = [
    (lib.cmakeFeature "KEEPASSXC_BUILD_TYPE" "Release")
    (lib.cmakeBool "KPXC_FEATURE_UPDATES" false)
    (lib.cmakeBool "WITH_X11" true)
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    export LC_ALL="en_US.UTF-8"
    export QT_QPA_PLATFORM=offscreen
    export QT_PLUGIN_PATH="${qt6.qtbase}/${qt6.qtbase.qtPluginPrefix}"

    # testcli and testgui are flaky in the sandbox (nixpkgs skips them too).
    make test ARGS+="-E 'testcli|testgui' --output-on-failure"

    runHook postCheck
  '';

  nativeBuildInputs = [
    asciidoctor
    cmake
    pkg-config
    qt6.qttools
    qt6.wrapQtAppsHook
    wrapGAppsHook3
  ];

  dontWrapGApps = true;
  preFixup = ''
    qtWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  # Browser native-messaging manifests, from the nixpkgs package.
  postInstall = ''
    mkdir -p "$out/lib/mozilla/native-messaging-hosts"
    substituteAll "${path}/pkgs/by-name/ke/keepassxc/firefox-native-messaging-host.json" "$out/lib/mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"

    mkdir -p "$out/etc/chromium/native-messaging-hosts"
    substituteAll "${path}/pkgs/by-name/ke/keepassxc/chromium-native-messaging-host.json" "$out/etc/chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
  '';

  buildInputs = [
    botan3
    keyutils
    libusb1
    libx11
    libxi
    libxkbcommon
    libxtst
    minizip
    pcsclite
    qrencode
    qt6.qtbase
    qt6.qtsvg
    qt6.qtwayland
    readline
    zlib
  ];

  meta = {
    description = "Offline password manager with many features";
    homepage = "https://keepassxc.org/";
    changelog = "https://github.com/keepassxreboot/keepassxc/blob/${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.gpl2Plus;
    mainProgram = "keepassxc";
    platforms = lib.platforms.linux;
  };
})
