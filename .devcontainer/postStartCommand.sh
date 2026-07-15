#!/usr/bin/env bash
set -euo pipefail

echo "Validating mounted files and directories..."

# All bind mount targets defined in devcontainer.json (volumes excluded).
# Each entry must be pre-created in Dockerfile to avoid Docker creating them as root.
EXPECTED_MOUNTS=(
	"$HOME/.claude/"
	"$HOME/.claude.json"
	"$HOME/.gitconfig"
	"$HOME/.gitconfig.d/"
	"$HOME/.config/gh/"
)

validation_failed=false

# Check each expected mount
for mount_path in "${EXPECTED_MOUNTS[@]}"; do
	if [[ ! -e "$mount_path" ]]; then
		echo -e "\e[33mWARNING: Mount target not found: $mount_path\e[0m"
		validation_failed=true
	else
		echo "✓ Mount validated: $mount_path"
	fi
done

if [ "$validation_failed" = true ]; then
	echo ""
	echo -e "\e[33m================================================================================\e[0m"
	echo -e "\e[33m>>>                                WARNING                                   <<<\e[0m"
	echo -e "\e[33m>>>\t一部のマウントが見つかりませんが、開発は続行可能です。\e[0m"
	echo -e "\e[33m>>>\t必要に応じて devcontainer.json の mounts を確認してください。\e[0m"
	echo -e "\e[33m>>>\ttarget にはマウント先の full path が含まれるためユーザー名を変更した\e[0m"
	echo -e "\e[33m>>>\t場合修正が必要です。\e[0m"
	echo -e "\e[33m================================================================================\e[0m"
	echo ""
else
	echo "All mounts validated successfully!"
fi

# mise bootstrap: install or upgrade to pinned version
export PATH="$HOME/.local/bin:$PATH"
## renovate: datasource=github-releases packageName=jdx/mise versioning=calver:YYYY.M.D automerge=true
MISE_PINNED_VERSION="2026.7.3"

installed_version=""
if command -v mise > /dev/null 2>&1; then
	installed_version="$(mise --version | awk '{print $1}')"
fi

if [ "$installed_version" != "$MISE_PINNED_VERSION" ]; then
	echo "Installing mise v${MISE_PINNED_VERSION} (installed: ${installed_version:-none})..."
	curl -fsSL --retry 3 --retry-delay 2 --retry-connrefused \
		https://mise.jdx.dev/install.sh | MISE_VERSION="v${MISE_PINNED_VERSION}" bash
fi
mise --version

# GPG homedir: ensure 700 permissions (GPG refuses to run otherwise)
_gpg_home="${GNUPGHOME:-$HOME/.gnupg}"
mkdir -p "${_gpg_home}"
chmod 700 "${_gpg_home}"

# GPG: suppress local agent auto-start only when the host socket is forwarded.
# Without this guard, VS Code (which provides its own GPG forwarding) would have
# gpg.conf polluted with no-autostart, breaking all GPG operations.
_gpg_rtdir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -S "${_gpg_rtdir}/gnupg/S.gpg-agent" ]; then
	_gpg_conf="${_gpg_home}/gpg.conf"
	if [ ! -f "${_gpg_conf}" ] || ! grep -q '^no-autostart' "${_gpg_conf}"; then
		echo "no-autostart" >> "${_gpg_conf}"
		echo "GPG: added 'no-autostart' to ${_gpg_conf}"
	fi
	unset _gpg_conf
fi
unset _gpg_rtdir _gpg_home

# SSH: populate known_hosts with github.com host keys inside the container
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keyscan -H github.com > ~/.ssh/known_hosts 2>/dev/null
chmod 600 ~/.ssh/known_hosts

chmod +x .githooks/*
git config --local --unset core.hookspath || true
mise trust -y /app
mise settings add trusted_config_paths /app
mise install

echo "Installing Claude Code..."
mise run claudecode:install

# gh-sync:keep-start
# Project-specific dependencies are listed here.

# gh-sync:keep-end
