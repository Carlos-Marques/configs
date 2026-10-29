# configs

System configuration for a Mac ([nix-darwin](https://github.com/LnL7/nix-darwin))
and a Framework laptop ([NixOS](https://nixos.org)), with
[home-manager](https://nix-community.github.io/home-manager/) shared between them.

| Host | Config | Machine |
|---|---|---|
| `m4-machine-broke` | `darwin.nix` | MacBook (MDM-managed) |
| `framework-machine-broke` | `hosts/framework/` | Framework Laptop 13, Hyprland |

| File | Purpose |
|---|---|
| `flake.nix` | Inputs, `user`, hosts, outputs |
| `darwin.nix` | Mac system: nix settings, linux-builder, macOS defaults, AeroSpace, Homebrew |
| `hosts/framework/` | Framework system: hardware, disk layout (disko), Hyprland session |
| `home/default.nix` | User config shared by both: packages, shell, editor, git, Syncthing |
| `home/darwin.nix`, `home/linux.nix` | Per-platform user config (Hyprland keybinds mirror AeroSpace) |
| `templates/default` | Flake template for new projects |

## Apply

`rebuild` (a shell alias on both machines), or by hand:

```sh
sudo darwin-rebuild switch --flake ~/configs#m4-machine-broke   # Mac
sudo nixos-rebuild switch --flake ~/configs                     # Framework
```

The Mac's hostname is set by MDM and contains its serial number, so the config
is named `m4-machine-broke` instead and selected explicitly. The Framework's
hostname matches its config, so `nixos-rebuild` picks it automatically.

Update inputs with `nix flake update`. Format with `nix fmt`.

## Fresh Mac

1. Install Nix with the [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
   and Homebrew.
2. Comment out `nix.linux-builder.config` in `darwin.nix` (the customized builder
   image has to be built *on* a Linux builder, which doesn't exist yet), switch,
   then restore it and switch again.
3. Run `nix-index` once so `comma` / command-not-found have a database.

## Fresh Framework

1. BIOS (F2 at power-on): Security → Secure Boot → disable enforcement. The
   NixOS installer isn't signed for Secure Boot.
2. Write the minimal installer to a USB stick: download
   `latest-nixos-minimal-x86_64-linux.iso` from
   [channels.nixos.org](https://channels.nixos.org/), check it against the
   `.sha256` beside it, then on a Mac
   `sudo dd if=nixos.iso of=/dev/rdiskN bs=4m` (`diskutil list` for N).
3. Boot it (F12 → the USB stick). Get online with `nmtui` (networks that
   isolate clients, like the office Wi-Fi, block SSH between machines; a phone
   hotspot works), authorize the SSH key with
   `mkdir -p ~/.ssh && curl -sL https://github.com/Carlos-Marques.keys >> ~/.ssh/authorized_keys`
   so the install can be driven over SSH, and note the address from `ip -4 a`.
4. Pick the mainboard module: `lscpu | grep 'Model name'`, then set
   `mainboard` in `hosts/framework/default.nix` (the table there maps CPU to
   module).
5. Replace the placeholder hardware config:
   `nixos-generate-config --no-filesystems --show-hardware-config > hosts/framework/hardware-configuration.nix`.
6. Check the disk is `/dev/nvme0n1` (`lsblk`; else edit `disko.nix`), then
   partition, encrypt and mount it (wipes the disk). disko reads the disk
   passphrase from `/tmp/secret.key`; write it on the laptop's console with
   `read -rs p && printf %s "$p" | sudo tee /tmp/secret.key >/dev/null`, then:
   `sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#framework-machine-broke`
7. `sudo nixos-install --flake .#framework-machine-broke --no-root-passwd`,
   then set the user's password on the console:
   `sudo nixos-enter -c 'passwd carlosmarques'`. **Don't skip this**: the
   account starts locked, and sudo and `fprintd-enroll` both need the password,
   so without it the only way back in is booting the USB stick, opening LUKS,
   mounting the `/root` and `/nix` subvolumes and running the same command.
   Delete `/tmp/secret.key`, reboot.
8. After the first login: `fprintd-enroll` for the fingerprint reader, copy
   the KeePassXC key file over (see Passwords), and accept the new device in
   Syncthing on another peer, then add its ID to `home/default.nix`.

Hyprland uses the same keys as AeroSpace on the Mac, with Alt as the modifier.
Super takes the Mac's Cmd shortcuts: Super+Return terminal, Super+Space
launcher, Super+Q close, Super+Ctrl+Q lock, Super+Shift+4/3 screenshot,
Super+Shift+Escape log out.

## Passwords

One KeePass database, synced as a file by Syncthing, opened natively on every
device. No server.

| Piece | Where | Managed by |
|---|---|---|
| Database | `~/vault/vault.kdbx` (Syncthing folder `vault`, staggered versioning) | `home.nix` |
| Key file | `~/.config/keepassxc/vault.keyx` — **never inside a synced folder**; copy to each device out of band | you |
| macOS app | KeePassXC cask (signed build: required for Touch ID quick unlock) | `darwin.nix` |
| Brave | KeePassXC-Browser, force-installed by policy | `darwin.nix` |
| CLI | `keepassxc-cli` (master password; `merge`), symlinked to `/opt/homebrew/bin` by the cask | `darwin.nix` |
| CLI + Touch ID | `kpxc-cli` — talks to the running app over its browser socket, so a locked vault prompts Touch ID and each lookup goes through KeePassXC's access dialog. Hash-pinned, audited source | `pkgs/keepassxc-cli.nix` |
| Android | KeePassDX (F-Droid): open `vault.kdbx` from the Syncthing folder + key file; enable biometric unlock and set it as the Autofill service; in Brave, Settings → Autofill services → "Autofill using another service" | phone |

KeePassXC's own settings are mutable app state and are not declared
(home-manager can only link a read-only `keepassxc.ini`, which makes the app
error on every write). Set once in the GUI: Security → Quick Unlock; Browser
Integration → enable, tick Brave (this writes the native-messaging manifest);
General → "Automatically reload the database when modified externally" and
"Safely save database files".

`kpxc-cli` needs a one-time pairing while KeePassXC is open (`kpxc-cli setup`,
approve in the app; key lands in `~/.keepassxc/browser-api.json`, 0600). Then
`kpxc-cli show https://example.com -p` — Touch ID if locked, approval dialog,
entry. Lookups match on the entry's URL field, not its title. Exit codes:
`kpxc-cli exit-codes`.

Conflicts: if both sides edit while offline, Syncthing leaves a
`vault.sync-conflict-*.kdbx`. Merge it into the main file, never pick one:

```sh
keepassxc-cli merge -k ~/.config/keepassxc/vault.keyx ~/vault/vault.kdbx ~/vault/vault.sync-conflict-*.kdbx
```

## New project

```sh
nix flake new -t ~/configs <dir>   # or -t github:Carlos-Marques/configs
cd <dir> && direnv allow
```

## References

- [nix-darwin options](https://nix-darwin.github.io/nix-darwin/manual/)
- [home-manager options](https://nix-community.github.io/home-manager/options.xhtml)
