#!/usr/bin/env bash

update_target_device() {
	if [[ "${USE_LVM}" == "yes" ]]; then
		export TARGET_ROOT_DEVICE="/dev/${VOLUME_GROUP}/${LV_ROOT}"
	else
		export TARGET_ROOT_DEVICE="${ROOT_PART}"
	fi
}

setup_devices() {
	[[ -n "${BOOT_PART}" ]] && export BOOT_DEVICE="/dev/disk/by-uuid/$(blkid -s UUID -o value ${BOOT_PART})"
	export ROOT_DEVICE="/dev/disk/by-uuid/$(blkid -s UUID -o value ${ROOT_PART})"
	[[ -n "${SWAP_PART}" ]] && export SWAP_DEVICE="/dev/disk/by-uuid/$(blkid -s UUID -o value ${SWAP_PART})"
}

prepare_mutable_users_config() {
	if [[ "${MUTABLE_USERS}" == "yes" ]]; then
		export MUTABLE_USERS="true"
	else
		export MUTABLE_USERS="false"
	fi
}

prepare_ssh_password_config() {
	if [[ "${ENABLE_SSH_PASSWORD}" == "yes" ]]; then
		export ENABLE_SSH_PASSWORD="true"
	else
		export ENABLE_SSH_PASSWORD="false"
	fi
}

prepare_swap_config() {
	if [[ "${USE_SWAP}" == "yes" ]]; then
		require_variable "${SWAP_PART}" SWAP_PART
		export SWAP_CONFIG="{ device = \"${SWAP_DEVICE}\"; }"
	else
		unset SWAP_CONFIG
	fi
}

prepare_luks_config() {
if [[ -n "${PASSPHRASE}" ]]; then
[[ -z "${LUKS_NAME}" ]] && require_variable "${LUKS_NAME}" LUKS_NAME
export LUKS_CONFIG=$(cat <<LUKS

      initrd.luks.devices = [
  	    { name = "${LUKS_NAME}"; device = "${ROOT_DEVICE}"; preLVM = true; }
      ];
LUKS
)
else
	unset LUKS_CONFIG
fi
}

prepare_sshkey_config() {
	if [[ -n "${ROOT_SSH_KEYS}" ]]; then
		export ROOT_SSH_KEY_CONFIG="openssh.authorizedKeys.keys = [ ${ROOT_SSH_KEYS} ];";
	else
		unset ROOT_SSH_KEY_CONFIG
	fi
}

prepare_root_password_config() {
	if [[ -n "${ROOT_HASHED_PASSWORD}" ]]; then
		export ROOT_PASSWORD_CONFIG="hashedPassword = \"${ROOT_HASHED_PASSWORD}\";";
	else
		unset ROOT_PASSWORD_CONFIG
	fi
}

prepare_boot_config() {
if [[ "${SEPARATE_BOOT_PART}" == "yes" ]]; then
export BOOTFS_CONFIG=$(cat <<BOOT_PART

  fileSystems."/boot" = { 
    device = "${BOOT_DEVICE}";
  };

BOOT_PART
)
else
	unset BOOTFS_CONFIG
fi

require_variable "${BOOTLOADER_DEVICE}" BOOTLOADER_DEVICE
}

activate_boot_partition() {
	if [[ -n "${BOOT_PART}" ]] && [[ "${BOOT_PART}" != "${ROOT_PART}" ]]; then
		export SEPARATE_BOOT_PART="yes"
	else
		export SEPARATE_BOOT_PART="no"
	fi
}

main() {
	for file in environment.conf library.sh; do
		source "${NIXOS_BOOTSTRAPPER_DIR}/${file}"
	done
	activate_boot_partition
	update_target_device
	prepare_mutable_users_config
	prepare_ssh_password_config
	prepare_sshkey_config
	prepare_root_password_config
	export SUCCESS_FILE="${NIXOS_BOOTSTRAPPER_DIR}/installation-successful"
	source "${NIXOS_BOOTSTRAPPER_DIR}/nix-installer.sh"
}

main
