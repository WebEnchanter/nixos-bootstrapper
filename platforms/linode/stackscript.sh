#!/bin/bash

# <UDF name="ROOT_SSH_KEYS"
#     Label="SSH Keys"
#     example="Public SSH keys for NixOS root user." />

# <UDF name="CHANNEL"
#     Label="NixOS Channel"
#     default="https://nixos.org/channels/nixos-14.12-small" />

# <UDF name="MUTABLE_USERS"
#     Label="Enable Mutable Users"
#     oneOf="yes,no"
#     default="no" />

# <UDF name="ROOT_HASHED_PASSWORD"
#     Label="Hashed Password"
#     default=""
#     example="This will be the hashed root password for NixOS. You don't have to provide one if you are not using mutable users. To generate a hashed password install 'mkpassword' package and run 'mkpasswd -m sha-512'." />

# <UDF name="ENABLE_SSH_PASSWORD"
#     Label="Enable SSH Password Authentication"
#     oneOf="yes,no"
#     default="no" />

# <UDF name="ROOT_PART_ENCRYPTION_PASSWORD"
#     Label="Root Partition Passhrase"
#     default=""
#     example="If you enter a passphrase here, your root partition will be encrypted using that passphrase." />

# <UDF name="LUKS_NAME"
#     Label="Encrypted Partition Name"
#     default="luksroot"
#     example="Name of the device that will be fed to luksOpen." />

# <UDF name="USE_LVM"
#     Label="Use LVM"
#     oneOf="yes,no"
#     default="no"
#     example="If you supplied a passphrase above, your root partition will use LVM and this option will be ignored." />

# <UDF name="VOLUME_GROUP"
#     Label="LVM Volume Group"
#     default="vg"
#     example="Will only be used if you supply a passhrase or if you opted to use LVM." />

# <UDF name="LV_ROOT"
#     Label="LVM LV Name"
#     default="root"
#     example="LVM Logical Volume name for root partion" />

# <UDF name="USE_SWAP"
#     Label="Use Linode Swap Disk"
#     oneOf="yes,no"
#     default="yes"
#     example="If you select 'yes', your NixOS machine will use the provided Linode swap disk as it's swap device. Otherwise swap will not be enabled by default. You can always enable it via NixOS later. If you are encrypting your root partition and you want to encrypt swap as well then select 'no'." />

# <UDF name="SWAP_PART"
#     Label="Swap Disk"
#     oneOf="/dev/xvdb"
#     default="/dev/xvdb"
#     example="You can't change this. This script expects that your swap disk will be mounted on /dev/xvdb if you opted to use Linode's swap disk above." />

# <UDF name="BOOT_PART"
#     Label="Boot Disk"
#     oneOf="/dev/xvdc,/dev/xvdd"
#     default="/dev/xvdc"
#     example="If you leave this as /dev/xvdc you will have a separate boot partition. This is necessary if you are using LVM on root or if you are encrypting the root partition. Changing it to /dev/xvdd (same partition as root) will disable a separate boot partition." />

# <UDF name="ROOT_PART"
#     Label="Root Disk"
#     oneOf="/dev/xvdd"
#     default="/dev/xvdd"
#     example="You can't change this. This script expects that your root disk will be mounted on /dev/xvdd when you boot your linode for the first time." />

export USER=root
export PASSPHRASE="${ROOT_PART_ENCRYPTION_PASSWORD}"
export NIXOS_BOOTSTRAPPER_DIR='/root/nixos-bootstrapper'
export ENV_FILE="${NIXOS_BOOTSTRAPPER_DIR}/environment.conf"
mkdir -p "${NIXOS_BOOTSTRAPPER_DIR}"

populate_env_file() {
	cp "${ENV_FILE}.default" "${ENV_FILE}" 
	sed -i "s/CHANNEL='.*'/CHANNEL='${CHANNEL}'/" 						"${ENV_FILE}"
	sed -i "s/MUTABLE_USERS='.*'/MUTABLE_USERS='${MUTABLE_USERS}'/" 			"${ENV_FILE}"
	sed -i "s/ROOT_HASHED_PASSWORD='.*'/ROOT_HASHED_PASSWORD='${ROOT_HASHED_PASSWORD}'/"	"${ENV_FILE}"
	sed -i "s/ENABLE_SSH_PASSWORD='.*'/ENABLE_SSH_PASSWORD='${ENABLE_SSH_PASSWORD}'/" 	"${ENV_FILE}"
	sed -i "s/ROOT_SSH_KEY='.*'/ROOT_SSH_KEY='${ROOT_SSH_KEY}'/" 				"${ENV_FILE}"
	# For security reasons we can't write the passhrase to disk so we have to prompt for it instead
	[[ -n "${PASSPHRASE}" ]] && sed -i "s/PASSPHRASE='.*'/PASSPHRASE='prompt'/"		"${ENV_FILE}"
	sed -i "s/LUKS_NAME='.*'/LUKS_NAME='${LUKS_NAME}'/" 					"${ENV_FILE}"
	sed -i "s/USE_LVM='.*'/USE_LVM='${USE_LVM}'/" 						"${ENV_FILE}"
	sed -i "s/VOLUME_GROUP='.*'/VOLUME_GROUP='${VOLUME_GROUP}'/" 				"${ENV_FILE}"
	sed -i "s/LV_ROOT='.*'/LV_ROOT='${LV_ROOT}'/" 						"${ENV_FILE}"
	sed -i "s/ROOT_PART='.*'/ROOT_PART='${ROOT_PART}'/" 					"${ENV_FILE}"
	sed -i "s/USE_SWAP='.*'/USE_SWAP='${USE_SWAP}'/" 					"${ENV_FILE}"
	sed -i "s/SWAP_PART='.*'/SWAP_PART='${SWAP_PART}'/" 					"${ENV_FILE}"
}

# Let's disable the default environment configuration.
# We are already configuring our environment through UDF variables.
touch "${ENV_FILE}"

# Download and run the NixOS installer
export NIXOS_BOOTSTRAPPER="${NIXOS_BOOTSTRAPPER_DIR}/nixos-bootstrapper.sh"
curl --output "${NIXOS_BOOTSTRAPPER}" 'https://github.com/webenchanter/nixos-bootstrapper/raw/master/nixos-bootstrapper.sh'
chmod +x "${NIXOS_BOOTSTRAPPER}"
"${NIXOS_BOOTSTRAPPER}"
if [[ -e "${SUCCESS_FILE}" ]]; then
	echo "Installation completed successfully..."
	poweroff
else
	echo "Looks like something has gone wrong during installation. Please login to fix."
	echo "See ${NIXOS_BOOTSTRAPPER_DIR}/installation.log for details..."
	echo "Persisting your information into the config file."
	populate_env_file
	sleep 30
fi
