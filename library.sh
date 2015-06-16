#!/usr/bin/env bash

print_error() {
	local error_message="${1}"; shift
	>&2 echo "ERROR: ${error_message}"
	exit 1
}

require_argument() {
	local arg="${1}"; shift
	local label="${1}"; shift
	local status=$([[ -z "$arg" ]])
	if [[ "${status}" -ne 0 ]]; then
		print_error "Missing required argument ${label}."
	fi
}

require_variable() {
	local var="${1}"; shift
	local label="${1}"; shift
	local status=$([[ -z "$var" ]])
	if [[ "${status}" -ne 0 ]]; then
		print_error "Missing required variable ${label}."
	fi
}

validate_device() {
	local device="${1}"
	echo 'q' | fdisk "${device}" >/dev/null 2>&1 || print_error "${device} is not a valid block device."
}

encrypt_device() {
	DEVICE="${1}"
	require_argument "${DEVICE}" DEVICE
	require_variable "${PASSPHRASE}" PASSPHRASE
	validate_device "${DEVICE}"
	if cryptsetup isLuks "${DEVICE}" >/dev/null 2>&1; then
		echo "INFO: Device is already encrypted. Doing nothing."
	else
		echo "INFO: Encrypting ${DEVICE}..."
		if [[ "${PASSPHRASE}" == "prompt" ]];  then
			cryptsetup luksFormat "${DEVICE}"
		else
			printf "${PASSPHRASE}" | cryptsetup --verbose --batch-mode luksFormat "${DEVICE}"
		fi
		ENCRYPT_STATUS=$?
		if [[ "${ENCRYPT_STATUS}" -eq 0 ]];  then
			echo "INFO: ${DEVICE} encrypted successfully."
		else
			echo "An error ocurred while encrypting ${DEVICE}."
		fi
	fi
}

open_encrypted_device() {
	DEVICE="${1}"
	NAME="${2}"
	require_argument "${DEVICE}" DEVICE
	require_argument "${NAME}" NAME
	require_variable "${PASSPHRASE}" PASSPHRASE
	validate_device "${DEVICE}"
	cryptsetup isLuks "${DEVICE}" || print_error "${DEVICE} is not encrypted."
	cryptsetup status "${NAME}"
	OPEN_STATUS="${?}"
	if [[ "${OPEN_STATUS}" -eq 0 ]];  then
		echo "INFO: Device is already open. Doing nothing."
	elif [[ "${OPEN_STATUS}" -eq 4 ]];  then
		if [[ "${PASSPHRASE}" == "prompt" ]];  then
			cryptsetup luksOpen "${DEVICE}" "${NAME}"
		else
			printf "${PASSPHRASE}" | cryptsetup luksOpen "${DEVICE}" "${NAME}"
		fi
		OPEN_STATUS="${?}"
		if [[ "${OPEN_STATUS}" -eq 0 ]];  then
			echo "${DEVICE} opened successfully."
		else
			echo "An error occurred while opening ${DEVICE}."
		fi
	else
		print_error "An error occured while opening the device."
	fi
}

open_device_if_necessary() {
	if [[ -n "${PASSPHRASE}" ]];  then
		[[ -z "${LUKS_NAME}" ]] && require_variable "${LUKS_NAME}" LUKS_NAME
		encrypt_device "${ROOT_PART}"
		open_encrypted_device "${ROOT_PART}" "${LUKS_NAME}"
	fi
}

prepare_logical_volumes_if_necessary() {
	if [[ "${USE_LVM}" == "yes" ]];  then
		[[ -z "${VOLUME_GROUP}" ]] && require_variable "${VOLUME_GROUP}" VOLUME_GROUP
		[[ -z "${LV_ROOT}" ]] && require_variable "${LV_ROOT}" LV_ROOT
		[[ -z "${LV_ROOT_EXTRA_OPTIONS}" ]] && require_variable "${LV_ROOT_EXTRA_OPTIONS}" LV_ROOT_EXTRA_OPTIONS
		vgscan --mknodes
		vgchange -ay
		if [[ -n "${PASSPHRASE}" ]];  then
			[[ -z "${LUKS_NAME}" ]] && require_variable "${LUKS_NAME}" LUKS_NAME
			PV="/dev/mapper/${LUKS_NAME}"
		else
			PV="${ROOT_PART}"
		fi
		pvdisplay "${PV}" >/dev/null 2>&1 || pvcreate "${PV}"
		vgdisplay "${VOLUME_GROUP}" >/dev/null 2>&1 || vgcreate "${VOLUME_GROUP}" "${PV}"
		lvdisplay "${LV_ROOT}" >/dev/null 2>&1 || lvcreate "${LV_ROOT_EXTRA_OPTIONS}" -n "${LV_ROOT}" "${VOLUME_GROUP}"
	fi
}

format_partitions_if_necessary() {
	if [[ "${SEPARATE_BOOT_PART}" == "yes" ]]; then
		[[ "$(blkid -s TYPE -o value ${BOOT_PART})" == "${BOOT_FSTYPE}" ]] \
			|| mkfs.${BOOT_FSTYPE} ${BOOT_FSOPTIONS} ${BOOT_PART} \
			|| print_error "Failed to format ${BOOT_PART}"
	fi
	if [[ "${USE_SWAP}" == 'yes' ]]; then
		require_variable "${SWAP_PART}" SWAP_PART
		swapoff --all
		mkswap -L swap "${SWAP_PART}"
	fi
	[[ "$(blkid -s TYPE -o value ${TARGET_ROOT_DEVICE})" == "${ROOT_FSTYPE}" ]] \
		|| mkfs.${ROOT_FSTYPE} ${ROOT_FSOPTIONS} ${TARGET_ROOT_DEVICE} \
		|| print_error "Failed to format ${TARGET_ROOT_DEVICE}"
}

mount_device() {
	DEVICE="${1}"
	MOUNT_POINT="${2}"
	require_argument "${DEVICE}" DEVICE
	require_argument "${MOUNT_POINT}" MOUNT_POINT
	validate_device "${DEVICE}"
	mkdir -p "${MOUNT_POINT}"
	if mountpoint -d "${MOUNT_POINT}" >/dev/null 2>&1; then
		umount "${MOUNT_POINT}"
	fi
	mount "${DEVICE}" "${MOUNT_POINT}" || print_error "Failed to mount ${MOUNT_POINT}." 
}

mount_partitions_if_necessary() {
	if [[ -n "${ROOT_PART}" ]]; then
		mount_device "${TARGET_ROOT_DEVICE}" /mnt
	fi
	if [[ "${SEPARATE_BOOT_PART}" == "yes" ]]; then
		mount_device "${BOOT_PART}" /mnt/boot
	fi
}

setup_nixbld_users() {
	local group_id=30000
	local group_name=nixbld
	if ! getent group "${group_id}" >/dev/null 2>&1; then
		groupadd -g "${group_id}" "${group_name}"
	fi
	for i in $(seq 1 10); do
		local user_id=$(expr "${group_id}" + "${i}")
		local user_name="${group_name}${i}"
		if ! id "${user_name}" >/dev/null 2>&1; then
			useradd \
				-u "${user_id}" \
				-c "Nix build user ${i}" \
				-d /var/empty \
				-s /noshell \
				"${user_name}"
		fi
		[[ "$(id ${user_name} -g)" != "${group_id}" ]] && usermod -a -G "${group_name}" "${user_name}" >/dev/null 2>&1
	done
}

install_nix() {
	setup_nixbld_users
	[[ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]] && source "${HOME}/.nix-profile/etc/profile.d/nix.sh"
	if command -v nix-env >/dev/null 2>&1; then
		echo "INFO: Nix package manager is already installed. Doing nothing."
	else
		curl https://nixos.org/nix/install | sh
		source "${HOME}/.nix-profile/etc/profile.d/nix.sh"
	fi
}

add_channel() {
	CHANNEL="${1}"
	CHANNEL_NAME="${2}"
	require_variable "${CHANNEL}" CHANNEL
	require_variable "${CHANNEL_NAME}" CHANNEL_NAME
	nix-channel --add "${CHANNEL}" "${CHANNEL_NAME}" || print_error "Failed to add channel."
	nix-channel --update || print_error "Failed to update channel."
}

create_default_config() {
local temp_config="${1}"
cat <<EOF > "${temp_config}" || print_error "Failed to create temporary config."
{ fileSystems."/" = {};
	boot.loader.grub.enable = false;
}
EOF
}

install_setup_software() {
	local temp_config=$(mktemp /tmp/temp-config.XXXXXXXXXX)
	create_default_config "${temp_config}"
	export NIX_PATH=nixpkgs="${HOME}/.nix-defexpr/channels/nixos:nixos=${HOME}/.nix-defexpr/channels/nixos/nixos"
	export NIXOS_CONFIG="${temp_config}"
	nix-env -i \
		-A config.system.build.nixos-install \
		-A config.system.build.nixos-option \
		-A config.system.build.nixos-generate-config \
		-f "<nixos>" || print_error "Failed to install setup software."
}

generate_hw_config() {
	nixos-generate-config --no-filesystems --root /mnt || print_error "Failed to generate config files."
}

generate_config_if_necessary() {
	CONFIG_FILE="/mnt/etc/nixos/configuration.nix"
	mkdir -p $(dirname "${CONFIG_FILE}")
	if [[ ! -e "${CONFIG_FILE}" ]]; then
		write_config "${CONFIG_FILE}" || print_error "An error occurred while generating config file."
	fi
	generate_hw_config || print_error "An error occurred while generating hardware config file."
}

install_nixos() {
	unset NIXOS_CONFIG
	local output=$(nixos-install --root /mnt)
	echo "${output}" | grep 'finalising the installation...' >/dev/null 2>&1 || print_error "An error occurred while running NixOS installer."
}

install_dependancies() {
	nix-env -i cryptsetup lvm2 xfsprogs
}

write_config() {
CONFIG_FILE="${1}"
local temp_config=$(mktemp /tmp/main-config.XXXXXXXXXX)
cat <<CONFIG > "${temp_config}"
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot = {
      loader.grub = {
 	    enable = true;
 	    version = 1;
 	    extraPerEntryConfig = "root (hd0)";
 	    device = "nodev";
      };${LUKS_DEVICES}
  };

  fileSystems."/" = {
    device = "${ROOT_DEVICE}";
    fsType = "${ROOT_FSTYPE}";
  };
${BOOTFS_CONFIG}

  swapDevices = [${SWAP_CONFIG}];

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
    passwordAuthentication = ${ENABLE_SSH_PASSWORD};
  };

  users = {
    mutableUsers = ${MUTABLE_USERS};
    extraUsers.root = {
      $ROOT_SSH_KEY_CONFIG
      $ROOT_PASSWORD_CONFIG
    };
  };

}
CONFIG

mv "${temp_config}" "${CONFIG_FILE}"
}
