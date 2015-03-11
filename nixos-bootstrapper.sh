#!/usr/bin/env bash

main() {
	[[ -z "${NIXOS_BOOTSTRAPPER_BASEURL}" ]] && NIXOS_BOOTSTRAPPER_BASEURL="https://raw.githubusercontent.com/webenchanter/nixos-bootstrapper/master"
	[[ -z "${NIXOS_BOOTSTRAPPER_DIR}" ]] && export NIXOS_BOOTSTRAPPER_DIR='/root/nixos-bootstrapper'
	mkdir -p "${NIXOS_BOOTSTRAPPER_DIR}"

	for FILE in environment.conf library.sh nix-installer.sh update-environment.sh nixos-installer.sh; do
		FILE_PATH="${NIXOS_BOOTSTRAPPER_DIR}/${FILE}"
		LOCAL_FILE="${FILE_PATH}"
		[[ "${FILE}" == 'environment.conf' ]] && [[ -f "${FILE_PATH}" ]] && LOCAL_FILE="${FILE_PATH}.default"
		wget --output-document "${LOCAL_FILE}" "${NIXOS_BOOTSTRAPPER_BASEURL}/${FILE}"
		if [[ "${FILE}" == 'nixos-installer.sh' ]]; then
			rm -f "${SUCCESS_FILE}"
			(source "${FILE_PATH}")
		elif [[ "${FILE}" == 'update-environment.sh' ]]; then
			source "${FILE_PATH}"
		fi
	done
}

(main 2>&1) | tee "${NIXOS_BOOTSTRAPPER_DIR}/installation.log"
