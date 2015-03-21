#!/usr/bin/env bash

main() {
	# Install Nix
	install_nix

	# Set the NixOS channel
	nix-channel --remove nixpkgs
	add_channel $CHANNEL nixos

	# Install the NixOS installation software
	install_setup_software
	install_dependancies
}

main
