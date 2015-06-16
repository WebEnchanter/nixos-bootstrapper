# NixOS Bootstrapper
If you love NixOS and wish you could use it to power your servers in the cloud then this project exists just for you.

This tool installs NixOS from within a Linux instance. Once you bootstrap your NixOS box, you can then delete the disk or partition with the current Linux distribution and start using NixOS exclusively.

## Quick Start
```bash
bash
NIXOS_BOOTSTRAPPER_DIR='/root/nixos-bootstrapper'
NIXOS_BOOTSTRAPPER_CONFIG_FILE="$NIXOS_BOOTSTRAPPER_DIR/environment.conf"
mkdir -p $NIXOS_BOOTSTRAPPER_DIR
curl --output $NIXOS_BOOTSTRAPPER_CONFIG_FILE https://raw.githubusercontent.com/webenchanter/nixos-bootstrapper/master/environment.conf
nano $NIXOS_BOOTSTRAPPER_CONFIG_FILE
curl --remote-name https://raw.githubusercontent.com/webenchanter/nixos-bootstrapper/master/nixos-bootstrapper.sh
source nixos-bootstrapper.sh
```
