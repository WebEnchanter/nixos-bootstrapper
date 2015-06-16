#!/usr/bin/env bash

set -e

main() {
	# If we opted for encryption, we will encrypt and/or open if needed
	open_device_if_necessary

	# If using LVM
	prepare_logical_volumes_if_necessary

	# Format partitions
	format_partitions_if_necessary

	# Mount default partitions
	mount_partitions_if_necessary

	# If this is a new installation, will we be able to login?
	if [[ ! -e "/mnt/etc/nixos/configuration.nix" ]] && [[ -z "${ROOT_SSH_KEYS}" ]] && [[ -z "${ROOT_HASHED_PASSWORD}" ]]; then
		print_error 'You did not setup an SSH key or hashed password for root. Open environment.conf and setup make sure either ROOT_SSH_KEY or ROOT_HASHED_PASSWORD is set.'
	fi

	# Generate a default configuration file for the bootable system
	setup_devices
	prepare_luks_config
	prepare_swap_config
	prepare_boot_config
	generate_config_if_necessary

	# Install NixOS
	install_nixos

	touch "${SUCCESS_FILE}"
}

main
