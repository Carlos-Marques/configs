# `kpxc-cli`: reads KeePassXC entries from the terminal through the running
# app's browser-extension socket, so a locked vault triggers Touch ID quick
# unlock instead of a master-password prompt, and every lookup goes through
# KeePassXC's own access dialog.
#
# Pinned on purpose. Both packages are small (~1.7k lines each) and were read
# in full before pinning; PyPI releases carry Sigstore attestations from the
# upstream repos and match their git tags. Nothing here changes until a
# version + hash is bumped in this file, unlike a Homebrew tap that tracks the
# author's HEAD.
#
# Bumping: update `version` and `hash` (sha256 from
# https://pypi.org/pypi/<name>/<version>/json, converted with
# `nix hash convert --hash-algo sha256 --to sri <hex>`), then re-read the diff
# between tags before switching.
{ lib, python3Packages }:

let
  keepassxc-browser-api = python3Packages.buildPythonPackage rec {
    pname = "keepassxc-browser-api";
    version = "1.5.0";
    pyproject = true;

    src = python3Packages.fetchPypi {
      pname = "keepassxc_browser_api";
      inherit version;
      hash = "sha256-HkKYGMCqCrKpkgPqpiWBWXSJTMJNatJZMwrc/nGr7aA=";
    };

    # setuptools-scm has no git metadata inside an sdist.
    env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

    build-system = with python3Packages; [
      setuptools
      setuptools-scm
    ];

    dependencies = [ python3Packages.pynacl ];
    # Upstream pins exact versions (`PyNaCl==1.6.2`); nixpkgs' are compatible.
    pythonRelaxDeps = true;

    nativeCheckInputs = [ python3Packages.pytestCheckHook ];
    pythonImportsCheck = [ "keepassxc_browser_api" ];
  };
in
python3Packages.buildPythonApplication rec {
  pname = "keepassxc-cli";
  version = "3.0.0";
  pyproject = true;

  src = python3Packages.fetchPypi {
    pname = "keepassxc_cli";
    inherit version;
    hash = "sha256-ZjXw00BdBSR7VVbphEJGLzZRhaFf0TEccmgC+6hFjfo=";
  };

  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    keepassxc-browser-api
    python3Packages.pyperclip
  ];
  pythonRelaxDeps = true;

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
  pythonImportsCheck = [ "keepassxc_cli" ];

  meta = {
    description = "CLI for KeePassXC over the browser-extension protocol, with biometric unlock";
    homepage = "https://github.com/mietzen/keepassxc-cli";
    license = lib.licenses.mit;
    mainProgram = "kpxc-cli";
  };
}
