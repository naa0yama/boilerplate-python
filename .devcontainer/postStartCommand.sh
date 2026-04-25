#!/usr/bin/env bash
set -euo pipefail

echo "Validating mounted files and directories..."

# List of expected mounted files and directories (optional)
EXPECTED_MOUNTS=(
	"$HOME/.claude.json"
	"$HOME/.claude/"
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
MISE_PINNED_VERSION="2026.4.18"

installed_version=""
if command -v mise > /dev/null 2>&1; then
	installed_version="$(mise --version | awk '{print $1}')"
fi

if [ "$installed_version" != "$MISE_PINNED_VERSION" ]; then
	echo "Installing mise v${MISE_PINNED_VERSION} (installed: ${installed_version:-none})..."
	MISE_VERSION="v${MISE_PINNED_VERSION}" \
		curl -fsSL --retry 3 --retry-delay 2 --retry-connrefused \
		https://mise.jdx.dev/install.sh | sh
fi
mise --version

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
