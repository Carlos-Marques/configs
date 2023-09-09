# configs
Repo for my configs

[The Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)

[Home Manager Manual](https://nix-community.github.io/home-manager/)

[Home Manager Options](https://nix-community.github.io/home-manager/options.html)

# Darwin
[nix-darwin](https://daiderd.com/nix-darwin/)

```bash
echo "{ \
  hostname = \"$(hostname -s)\"; \
  user = \"$USER\"; \
  homePath = \"$HOME\"; \
}" > darwin-variables.nix \
&& darwin-rebuild switch --flake .
```