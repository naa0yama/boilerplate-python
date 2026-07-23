# syntax=docker/dockerfile:1.25.0@sha256:0adf442eae370b6087e08edc7c50b552d80ddf261576f4ebd6421006b2461f12
#- -------------------------------------------------------------------------------------------------
#- Global
#-
ARG DEBIAN_FRONTEND=noninteractive \
	PIP_DEFAULT_TIMEOUT=100 \
	PIP_DISABLE_PIP_VERSION_CHECK=on \
	PIP_NO_CACHE_DIR=off \
	PYTHONFAULTHANDLER=1 \
	PYTHONHASHSEED=random \
	PYTHONUNBUFFERED=1 \
	TZ=${TZ:-Asia/Tokyo} \
	USER_GID=${USER_GID:-${USER_UID}} \
	USER_NAME=cuser \
	USER_UID=${USER_UID:-60001}


#- -------------------------------------------------------------------------------------------------
#- Builder Base
#-
FROM --platform=$BUILDPLATFORM python:3.14.6-slim-trixie@sha256:cea0e6040540fb2b965b6e7fb5ffa00871e632eef63719f0ea54bca189ce14a6 AS builder-base

ARG DEBIAN_FRONTEND \
	PIP_DEFAULT_TIMEOUT \
	PIP_DISABLE_PIP_VERSION_CHECK \
	PIP_NO_CACHE_DIR \
	PYTHONFAULTHANDLER \
	PYTHONHASHSEED \
	PYTHONUNBUFFERED \
	TZ \
	USER_GID \
	USER_NAME \
	USER_UID

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
SHELL [ "/bin/bash", "-c" ]

# set Timezone
RUN echo "**** set Timezone ****" && \
	set -euxo pipefail && \
	ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
	\
	echo "**** Dependencies ****" && \
	rm -f /etc/apt/apt.conf.d/docker-clean && \
	echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
	echo "**** Dependencies ****" && \
	set -euxo pipefail && \
	apt-get -y update && \
	apt-get -y upgrade && \
	apt-get -y install --no-install-recommends \
	bash \
	bash-completion \
	build-essential \
	ca-certificates \
	curl \
	git \
	gnupg \
	jq \
	nano \
	openssh-client \
	patchelf \
	sudo \
	wget

# gh-sync:keep-start
# Project-specific dependencies are listed here.

# gh-sync:keep-end

RUN echo "**** Create user ****" && \
	set -euxo pipefail && \
	groupadd --gid "${USER_GID}" "${USER_NAME}" && \
	useradd -s /bin/bash --uid "${USER_UID}" --gid "${USER_GID}" -m "${USER_NAME}" && \
	echo "${USER_NAME}:password" | chpasswd && \
	passwd -d "${USER_NAME}"

RUN echo "**** Add sudo user ****" && \
	set -euxo pipefail && \
	echo -e "${USER_NAME}\tALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USER_NAME}"

RUN echo "**** Create XDG runtime dir ****" && \
	set -euxo pipefail && \
	mkdir -p /run/user/${USER_UID}/gnupg && \
	chown -R ${USER_NAME}:${USER_NAME} /run/user/${USER_UID} && \
	chmod 700 /run/user/${USER_UID} /run/user/${USER_UID}/gnupg


#- -------------------------------------------------------------------------------------------------
#- Development
#-
FROM --platform=$BUILDPLATFORM builder-base AS development

# User level settings
USER ${USER_NAME}

RUN echo "**** Directory Create ****" && \
	set -euxo pipefail && \
	mkdir -p \
	~/.claude \
	~/.config \
	~/.config/gh \
	~/.config/mise \
	~/.gitconfig.d \
	~/.gnupg \
	~/.local \
	~/.local/bin \
	~/.local/share \
	~/.local/share/claude \
	~/.local/share/mise \
	~/.ssh \
	\
	&& \
	chmod 700 ~/.gnupg ~/.ssh && \
	touch \
	~/.claude.json \
	~/.gitconfig \
	~/.gnupg/pubring.kbx

RUN <<EOF
echo "**** add '~/.bashrc mise and claude code ****"
set -euxo pipefail

cat <<- '_DOC_' >> ~/.bashrc
# mise
eval "$(~/.local/bin/mise activate bash)"

# This requires bash-completion to be installed
if [ ! -f "${HOME}/.local/share/bash-completion/completions/mise" ]; then
	~/.local/bin/mise use -g usage
	mkdir -p "${HOME}/.local/share/bash-completion/completions/"
	~/.local/bin/mise completion bash --include-bash-completion-lib > "${HOME}/.local/share/bash-completion/completions/mise"
fi

# ~/.local/bin (Claude Code, OpenObserve, etc.)
case ":$PATH:" in
	*:"$HOME/.local/bin":*) ;;
	*) export PATH="$HOME/.local/bin:$PATH" ;;
esac
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export GPG_TTY=$(tty 2>/dev/null || true)
alias cc="claude --dangerously-skip-permissions"

_DOC_
EOF

# gh-sync:keep-start
# Project-specific dependencies are listed here.

# gh-sync:keep-end
