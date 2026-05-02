#!/usr/bin/env bash
# .devcontainer/traefik.sh <command>
# Commands: setup | up | down | exec | status
#
# Must be run on the WSL2 host, not inside a devcontainer.
set -euo pipefail

readonly TRAEFIK_BIN="${HOME}/.local/bin/traefik"
readonly TRAEFIK_CONFIG="${HOME}/.config/traefik/traefik.yml"
readonly TRAEFIK_DYNAMIC_DIR="${HOME}/.config/traefik/dynamic"
readonly TRAEFIK_DYNAMIC_CONTAINER_PATH=/traefik-dynamic
readonly TRAEFIK_SERVICE="${HOME}/.config/systemd/user/traefik.service"
readonly TRAEFIK_PORT_ROUTER=8080
readonly TRAEFIK_PORT_DASHBOARD=8081

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

_host_check() {
	if [ "${MISE_ENV:-}" = "devcontainer" ] || [ -f "/.dockerenv" ]; then
		echo "Error: must be run on the WSL2 host, not inside a devcontainer." >&2
		exit 1
	fi
}

_workspace() {
	git rev-parse --show-toplevel
}

_project() {
	basename "$(_workspace)"
}

_branch() {
	local workspace raw
	workspace="$(_workspace)"
	raw="$(git -C "${workspace}" branch --show-current 2>/dev/null || true)"
	if [ -z "${raw}" ]; then
		raw="detached-$(git -C "${workspace}" rev-parse --short HEAD)"
	fi
	printf '%s' "${raw}" \
		| tr '[:upper:]' '[:lower:]' \
		| sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//' \
		| cut -c1-63
}

# Read the container user's UID from devcontainer.json build args
_container_uid() {
	_jsonc "$(_workspace)/.devcontainer/devcontainer.json" \
		| jq -r '.build.args.USER_UID // "1000"'
}

# Strip single-line comments (//) from JSONC before passing to jq
_jsonc() {
	sed -e '/^[[:space:]]*\/\//d' -e 's|[[:space:]]//[^"]*$||g' "${1}"
}

_ports() {
	local devcontainer_json
	devcontainer_json="$(_workspace)/.devcontainer/devcontainer.json"
	_jsonc "${devcontainer_json}" | jq -r '.portsAttributes | keys[]' 2>/dev/null || true
}

# Find container ID for the current workspace (running or stopped).
# Uses devcontainer.local_folder label (set by devcontainer CLI) so the lookup
# is stable across branch changes inside the container.
_container_id() {
	local workspace
	workspace="$(_workspace)"
	docker ps -aq --filter "label=devcontainer.local_folder=${workspace}"
}

# Find running container ID only.
_running_container_id() {
	local workspace
	workspace="$(_workspace)"
	docker ps -q --filter "label=devcontainer.local_folder=${workspace}"
}

_ensure_network() {
	docker network inspect devcontainer-traefik >/dev/null 2>&1 \
		|| docker network create devcontainer-traefik
}

# Write traefik file-provider YAML for all ports of one container.
# Usage: _write_routes <container_id> <project> <branch> <ip> <ports_newline_separated>
_write_routes() {
	local cid="${1}" project="${2}" branch="${3}" ip="${4}" ports="${5}"
	local cid_short="${cid:0:12}"
	local dest="${TRAEFIK_DYNAMIC_DIR}/${project}-${cid_short}.yml"
	local bt='`'

	{
		printf 'http:\n'
		printf '  routers:\n'
		while IFS= read -r port; do
			[ -z "${port}" ] && continue
			local router="p${port}-${branch}--${project}"
			local fqdn="p${port}.${branch}.${project}.localhost"
			printf '    %s:\n' "${router}"
			printf '      rule: "Host(%s%s%s)"\n' "${bt}" "${fqdn}" "${bt}"
			printf '      entryPoints:\n'
			printf '        - web\n'
			printf '      service: %s\n' "${router}"
		done <<< "${ports}"
		printf '  services:\n'
		while IFS= read -r port; do
			[ -z "${port}" ] && continue
			local router="p${port}-${branch}--${project}"
			printf '    %s:\n' "${router}"
			printf '      loadBalancer:\n'
			printf '        servers:\n'
			printf '          - url: "http://%s:%s"\n' "${ip}" "${port}"
		done <<< "${ports}"
	} > "${dest}"
	echo "Wrote ${dest}"
}

# Remove the file-provider YAML for a container.
_remove_routes() {
	local cid="${1}" project="${2}"
	local cid_short="${cid:0:12}"
	local dest="${TRAEFIK_DYNAMIC_DIR}/${project}-${cid_short}.yml"
	rm -f "${dest}" && echo "Removed ${dest}"
}

# Query GitHub releases API for the latest traefik tag (e.g. "v3.4.1")
_traefik_latest() {
	curl -sfSL --retry 3 \
		https://api.github.com/repos/traefik/traefik/releases/latest \
		| jq -r '.tag_name'
}

# Print the installed traefik version tag (e.g. "v3.4.0"), or empty string
_traefik_installed() {
	if [ ! -x "${TRAEFIK_BIN}" ]; then
		echo ""
		return
	fi
	# "traefik version" output: "Version:      3.4.1" (variable spacing, no "v" prefix)
	"${TRAEFIK_BIN}" version 2>/dev/null \
		| grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
		| head -1 \
		| sed 's/^/v/' \
		|| echo ""
}

_traefik_install_version() {
	local version arch filename url tmpfile checksums_url checksums_file expected actual

	version="${1}"

	case "$(uname -m)" in
		x86_64)  arch="amd64" ;;
		aarch64) arch="arm64" ;;
		*)
			echo "Error: unsupported architecture $(uname -m)" >&2
			exit 1
			;;
	esac

	filename="traefik_${version}_linux_${arch}.tar.gz"
	url="https://github.com/traefik/traefik/releases/download/${version}/${filename}"
	checksums_url="https://github.com/traefik/traefik/releases/download/${version}/traefik_${version}_checksums.txt"

	tmpfile="$(mktemp)"
	checksums_file="$(mktemp)"

	echo "Downloading traefik ${version} (${arch})..." >&2
	if ! curl -fSL --retry 3 --retry-delay 2 --retry-connrefused -o "${tmpfile}" "${url}"; then
		rm -f "${tmpfile}" "${checksums_file}"
		exit 1
	fi

	echo "Verifying checksum..." >&2
	if ! curl -fSL --retry 3 --retry-delay 2 --retry-connrefused -o "${checksums_file}" "${checksums_url}"; then
		rm -f "${tmpfile}" "${checksums_file}"
		echo "Error: failed to download checksums file" >&2
		exit 1
	fi

	expected="$(awk -v f="${filename}" '$2==f{print $1}' "${checksums_file}")"
	actual="$(sha256sum "${tmpfile}" | awk '{print $1}')"
	rm -f "${checksums_file}"

	if [ -z "${expected}" ]; then
		rm -f "${tmpfile}"
		echo "Error: ${filename} not found in checksums file" >&2
		exit 1
	fi
	if [ "${expected}" != "${actual}" ]; then
		rm -f "${tmpfile}"
		echo "Error: checksum mismatch (expected ${expected}, got ${actual})" >&2
		exit 1
	fi

	mkdir -p "${HOME}/.local/bin"
	if ! tar -xzf "${tmpfile}" -C "${HOME}/.local/bin" traefik; then
		rm -f "${tmpfile}"
		echo "Error: failed to extract traefik binary" >&2
		exit 1
	fi
	rm -f "${tmpfile}"
	chmod +x "${TRAEFIK_BIN}"
	echo "Installed traefik ${version} to ${TRAEFIK_BIN}" >&2
}

# Check installed version vs latest; install or update as needed.
# Prints one of: "installed", "updated", "already-latest"
_traefik_ensure_latest() {
	local installed latest
	installed="$(_traefik_installed)"
	latest="$(_traefik_latest)"

	if [ -z "${latest}" ]; then
		echo "Warning: could not fetch latest traefik version from GitHub." >&2
		if [ -z "${installed}" ]; then
			echo "Error: traefik is not installed and version check failed." >&2
			exit 1
		fi
		echo "already-latest"
		return
	fi

	if [ -z "${installed}" ]; then
		_traefik_install_version "${latest}"
		echo "installed"
	elif [ "${installed}" != "${latest}" ]; then
		echo "Updating traefik ${installed} -> ${latest}" >&2
		_traefik_install_version "${latest}"
		echo "updated"
	else
		echo "traefik ${installed}: already at latest" >&2
		echo "already-latest"
	fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_setup() {
	_host_check

	_traefik_ensure_latest >/dev/null
	# Show final installed version
	echo "traefik: $(_traefik_installed)"

	_ensure_network
	mkdir -p "$(dirname "${TRAEFIK_CONFIG}")" "$(dirname "${TRAEFIK_SERVICE}")" "${TRAEFIK_DYNAMIC_DIR}"

	# "traefik" entrypoint name overrides Traefik v3's built-in default (:8080).
	# Without this, api.insecure creates an implicit "traefik" entrypoint at :8080
	# which conflicts with the "web" entrypoint on the same port.
	cat > "${TRAEFIK_CONFIG}" << YAML
entryPoints:
  web:
    address: ":${TRAEFIK_PORT_ROUTER}"
  traefik:
    address: ":${TRAEFIK_PORT_DASHBOARD}"
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: devcontainer-traefik
  file:
    directory: "${TRAEFIK_DYNAMIC_DIR}"
    watch: true
api:
  dashboard: true
  insecure: true
YAML
	echo "Wrote ${TRAEFIK_CONFIG}"

	cat > "${TRAEFIK_SERVICE}" << UNIT
[Unit]
Description=Traefik reverse proxy for devcontainers
After=network.target

[Service]
ExecStart=${TRAEFIK_BIN} --configfile=${TRAEFIK_CONFIG}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
	echo "Wrote ${TRAEFIK_SERVICE}"

	systemctl --user daemon-reload
	systemctl --user enable traefik.service

	if systemctl --user is-active --quiet traefik.service; then
		echo "Restarting traefik to apply config..."
		systemctl --user restart traefik.service
	else
		systemctl --user start traefik.service
	fi

	systemctl --user status traefik.service --no-pager
	echo ""
	echo "Traefik router:    http://localhost:${TRAEFIK_PORT_ROUTER}"
	echo "Traefik dashboard: http://localhost:${TRAEFIK_PORT_DASHBOARD}/dashboard/"
}

cmd_up() {
	local workspace project branch ports run_args tmpfile result container_id
	local _cuid _gpg_sock _gpg_home

	_host_check

	# Check traefik binary exists; install/update if needed
	local update_result
	update_result="$(_traefik_ensure_latest)"
	case "${update_result}" in
		installed) echo "traefik installed: $(_traefik_installed)" ;;
		updated)   echo "traefik updated: $(_traefik_installed)" ;;
	esac

	cmd_down
	_ensure_network

	workspace="$(_workspace)"
	project="$(_project)"
	branch="$(_branch)"
	ports="$(_ports)"

	if [ -z "${ports}" ]; then
		echo "Warning: no portsAttributes found in devcontainer.json." >&2
	fi

	run_args='["--label=devcontainer.project='"${project}"'"'
	run_args="${run_args},\"--env=COLORTERM=${COLORTERM:-}\""
	run_args="${run_args},\"--env=TERM=${TERM:-xterm-256color}\""
	run_args="${run_args},\"--env=TRAEFIK_MANAGED=1\""
	run_args="${run_args},\"--env=TRAEFIK_PROJECT=${project}\""
	run_args="${run_args},\"--env=TRAEFIK_DYNAMIC_DIR=${TRAEFIK_DYNAMIC_CONTAINER_PATH}\""
	run_args="${run_args},\"--env=TRAEFIK_API_BASE=http://host.docker.internal:${TRAEFIK_PORT_DASHBOARD}\""
	run_args="${run_args},\"--mount=type=bind,source=${TRAEFIK_DYNAMIC_DIR},target=${TRAEFIK_DYNAMIC_CONTAINER_PATH}\""
	run_args="${run_args},\"--add-host=host.docker.internal:host-gateway\""

	# Resolve container UID once for XDG runtime dir paths
	_cuid="$(_container_uid)"

	# SSH agent forwarding
	if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
		run_args="${run_args},\"--mount=type=bind,source=${SSH_AUTH_SOCK},target=/run/user/${_cuid}/ssh-agent.sock\""
		run_args="${run_args},\"--env=SSH_AUTH_SOCK=/run/user/${_cuid}/ssh-agent.sock\""
	else
		echo "Note: SSH_AUTH_SOCK not available; skipping SSH agent forwarding." >&2
	fi

	# GPG agent socket forwarding + public keyring
	_gpg_sock="$(gpgconf --list-dirs agent-socket 2>/dev/null || true)"
	if [ -n "${_gpg_sock}" ] && [ -S "${_gpg_sock}" ]; then
		run_args="${run_args},\"--mount=type=bind,source=${_gpg_sock},target=/run/user/${_cuid}/gnupg/S.gpg-agent\""
	else
		echo "Note: GPG agent socket not available; skipping GPG forwarding." >&2
	fi
	# S.gpg-agent.extra is intentionally NOT forwarded: gpg(1) connects to S.gpg-agent
	# only. The extra socket is for restricted remote clients (e.g., SSH RemoteForward);
	# nothing inside this container needs it.
	# GPG public keyring: needed so gpg knows which key to request from the agent
	_gpg_home="${GNUPGHOME:-$HOME/.gnupg}"
	if [ -f "${_gpg_home}/pubring.kbx" ]; then
		run_args="${run_args},\"--mount=type=bind,source=${_gpg_home}/pubring.kbx,target=/home/cuser/.gnupg/pubring.kbx,readonly\""
	fi
	# trustdb.gpg is intentionally NOT mounted: GPG writes maintenance updates to it,
	# and a readonly mount causes write warnings on every invocation. GPG auto-creates
	# a fresh trustdb inside the container; trust is not needed for signing.

	run_args="${run_args}]"

	# --override-config replaces (not merges) devcontainer.json, so we must
	# merge our runArgs into the full base config before passing it.
	tmpfile="$(mktemp --suffix=.json)"
	# shellcheck disable=SC2064
	trap "rm -f '${tmpfile}'" EXIT
	_jsonc "${workspace}/.devcontainer/devcontainer.json" \
		| jq --argjson args "${run_args}" '. + {runArgs: $args}' \
		> "${tmpfile}"

	result="$(devcontainer up --workspace-folder "${workspace}" --override-config "${tmpfile}")"
	container_id="$(printf '%s' "${result}" | jq -r '.containerId')"

	if [ -z "${container_id}" ] || [ "${container_id}" = "null" ]; then
		echo "ERROR: failed to get containerId from devcontainer up" >&2
		printf '%s\n' "${result}" >&2
		exit 1
	fi

	local container_ip=""
	container_ip="$(docker inspect "${container_id}" \
		--format '{{(index .NetworkSettings.Networks "devcontainer-traefik").IPAddress}}' \
		2>/dev/null || true)"
	if [ -z "${container_ip}" ]; then
		docker network connect devcontainer-traefik "${container_id}"
		container_ip="$(docker inspect "${container_id}" \
			--format '{{(index .NetworkSettings.Networks "devcontainer-traefik").IPAddress}}' \
			2>/dev/null || true)"
	fi

	if [ -n "${ports}" ] && [ -n "${container_ip}" ]; then
		_write_routes "${container_id}" "${project}" "${branch}" "${container_ip}" "${ports}"
	fi

	# Splash
	echo ""
	echo "=================================================="
	echo "  ${project} / ${branch}"
	echo "=================================================="
	echo ""
	echo "  Container: ${container_id:0:12}"
	echo ""
	if [ -n "${ports}" ]; then
		echo "  URLs:"
		while IFS= read -r port; do
			[ -z "${port}" ] && continue
			echo "    http://p${port}.${branch}.${project}.localhost:${TRAEFIK_PORT_ROUTER}"
		done <<< "${ports}"
		echo ""
	fi
	echo "  Traefik router:    http://localhost:${TRAEFIK_PORT_ROUTER}"
	echo "  Traefik dashboard: http://localhost:${TRAEFIK_PORT_DASHBOARD}/dashboard/"
	echo ""
	echo "  Reconnect: mise run dev:exec"
	echo "=================================================="
	echo ""

	_exec_and_watch
}

cmd_down() {
	local project container_id

	_host_check

	project="$(_project)"
	container_id="$(_container_id)"

	if [ -z "${container_id}" ]; then
		echo "No devcontainer found for ${project}"
		return 0
	fi

	while IFS= read -r cid; do
		[ -z "${cid}" ] && continue
		_remove_routes "${cid}" "${project}"
		docker rm -f "${cid}" > /dev/null
		echo "Stopped: ${project} (${cid})"
	done <<< "${container_id}"
}

_exec_and_watch() {
	local workspace

	workspace="$(_workspace)"

	devcontainer exec --workspace-folder "${workspace}" bash || true

	# Capture the specific container ID at bash-exit time so the background job
	# targets only this container, not a new one started by a concurrent dev:up.
	local exited_cid exited_project
	exited_cid="$(_running_container_id)"
	exited_project="$(_project)"

	echo "Shell exited. Container stopping in 10s... (mise run dev:exec to reconnect)"
	if [ -n "${exited_cid}" ]; then
		( sleep 10
		  _remove_routes "${exited_cid}" "${exited_project}"
		  docker rm -f "${exited_cid}" > /dev/null 2>&1 || true ) &
	fi
}

cmd_exec() {
	local container_id

	_host_check

	container_id="$(_running_container_id)"

	if [ -z "${container_id}" ]; then
		echo "Container not running. Starting..."
		cmd_up
		return
	fi

	_exec_and_watch
}

cmd_status() {
	_host_check
	docker ps \
		--filter "label=devcontainer.project" \
		--format 'table {{.ID}}\t{{.Status}}\t{{.Label "devcontainer.project"}}'
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "${1:-}" in
	setup)  cmd_setup  ;;
	up)     cmd_up     ;;
	down)   cmd_down   ;;
	exec)   cmd_exec   ;;
	status) cmd_status ;;
	*)
		echo "Usage: $0 {setup|up|down|exec|status}" >&2
		exit 1
		;;
esac
