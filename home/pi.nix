# Pi (pi.dev) on the Claude Pro/Max subscription, through the official Claude
# Code CLI: the pi-claude-code extension sends Pi's model calls to `claude -p`
# and Pi runs the tools itself. Claude Code alone owns the login (`claude auth
# login`); nothing here reads or stores its credentials, and Pi's own
# `/login anthropic` (third-party OAuth, billed per token) is never used.
{ lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  # Pinned commit: Pi clones git packages into ~/.pi/agent/git on first start
  # and never moves a pinned ref by itself. After bumping it, run
  # `pi update --extensions` (the checkout's path has no ref in it, so an
  # existing clone is only reconciled by an update).
  claudeCodeExtension = "git:github.com/earendil-works/pi-claude-code@70abb65186592ca788b29b3db22c3160d629c41f";

  # Each of these moves Claude Code off the subscription (API key, proxy,
  # Bedrock/Vertex/Foundry), and ANTHROPIC_OAUTH_TOKEN would let Pi's built-in
  # Anthropic provider log in itself. A project's direnv or a stray export
  # could set one, so the wrappers drop them rather than trust the caller.
  # PI_CLAUDE_CODE_ALLOW_USAGE_CREDITS stays unset so turns that would be
  # charged to extra usage fail instead.
  unsetBillingOverrides =
    lib.concatMap
      (name: [
        "--unset"
        name
      ])
      [
        "ANTHROPIC_API_KEY"
        "ANTHROPIC_AUTH_TOKEN"
        "ANTHROPIC_BASE_URL"
        "ANTHROPIC_FOUNDRY_API_KEY"
        "ANTHROPIC_OAUTH_TOKEN"
        "CLAUDE_CODE_USE_BEDROCK"
        "CLAUDE_CODE_USE_VERTEX"
        "CLAUDE_CODE_USE_FOUNDRY"
        "PI_CLAUDE_CODE_ALLOW_USAGE_CREDITS"
      ];

  wrapped =
    pkg: exe: extraArgs:
    pkgs.symlinkJoin {
      inherit (pkg) name meta;
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${exe} ${lib.escapeShellArgs (unsetBillingOverrides ++ extraArgs)}
      '';
    };

  # On the Mac, Claude Code is the Homebrew cask (darwin.nix: Anthropic's own
  # binary from downloads.claude.ai), which comes first on PATH and keeps
  # itself current; a second `claude` from nixpkgs would only be shadowed.
  # Don't drop that cask lightly: `cleanup = "zap"` trashes ~/.claude.json
  # with it. Linux gets nixpkgs' build of the same binary, only wrapped.
  claude = if isDarwin then null else wrapped pkgs.claude-code "claude" [ ];
  claudeCommand = if isDarwin then "/opt/homebrew/bin/claude" else "${claude}/bin/claude";

  pi = wrapped pkgs.pi-coding-agent "pi" [
    # The extension runs this, not whatever `claude` comes first on PATH.
    "--set-default"
    "PI_CLAUDE_CODE_COMMAND"
    claudeCommand
    # Pi installs git packages with `git clone` + `npm install`; neither
    # ships with the nixpkgs package.
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [
      pkgs.git
      pkgs.nodejs
    ])
  ];

  # Pi rewrites settings.json itself (/model, `pi install`, `pi config`), so a
  # read-only home-manager link would break it. Merge only the package entry,
  # replacing any other ref of the same repo.
  addExtension = pkgs.writeShellScript "pi-add-claude-code" ''
    set -eu
    jq=${lib.getExe pkgs.jq}
    dir="$HOME/.pi/agent"
    settings="$dir/settings.json"
    mkdir -p "$dir"
    [ -s "$settings" ] || echo '{}' >"$settings"
    tmp=$(mktemp "$settings.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    if ! "$jq" --arg src ${lib.escapeShellArg claudeCodeExtension} '
      .packages = [
        (.packages // [])[]
        | select((if type == "string" then . else .source end)
                 | test("github\\.com/earendil-works/pi-claude-code") | not)
      ] + [$src]
    ' "$settings" >"$tmp"; then
      echo "pi: $settings is not valid JSON; add "${lib.escapeShellArg claudeCodeExtension}" to its packages by hand" >&2
      exit 0
    fi
    cmp -s "$tmp" "$settings" || mv "$tmp" "$settings"
  '';

  # Rule: no Pi-side Anthropic OAuth. Drops only that entry (its `type` is
  # checked, no secret is read out); other providers' logins stay.
  # mktemp creates the replacement 0600, like Pi's own auth.json.
  removePiAnthropicLogin = pkgs.writeShellScript "pi-remove-anthropic-oauth" ''
    set -eu
    jq=${lib.getExe pkgs.jq}
    auth="$HOME/.pi/agent/auth.json"
    [ -f "$auth" ] || exit 0
    "$jq" -e '.anthropic.type? == "oauth"' "$auth" >/dev/null 2>&1 || exit 0
    tmp=$(mktemp "$auth.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    "$jq" 'del(.anthropic)' "$auth" >"$tmp"
    mv "$tmp" "$auth"
    echo "pi: removed Pi's own Anthropic OAuth login; Claude goes through Claude Code" >&2
  '';
in
{
  home.packages = [ pi ] ++ lib.optional (claude != null) claude;

  home.activation.piClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${removePiAnthropicLogin}
    run ${addExtension}
  '';
}
