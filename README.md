# pythonboilerplate

![coverage](https://raw.githubusercontent.com/naa0yama/boilerplate-python/badges/coverage.svg)
![test execution time](https://raw.githubusercontent.com/naa0yama/boilerplate-python/badges/time.svg)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![mise](https://img.shields.io/badge/mise-enabled-blue)](https://mise.jdx.dev)
[![Python](https://img.shields.io/badge/python-3.14-blue)](https://www.python.org)

Python で開発する時用ボイラープレート

## Getting Started

`mise` でツール一式 (Python, uv, dprint など) をプロビジョニングし、 `uv` で依存関係をインストールする。

```bash
# mise のインストール (未導入の場合)
# https://mise.jdx.dev/getting-started.html
curl https://mise.run | sh

# ツール一式のインストール (Python 3.14, uv, dprint, actionlint, ...)
mise install

# Python 依存関係のインストール
mise run install

# テスト実行
mise run test
```

### 主なコマンド

| コマンド              | 説明                    |
| --------------------- | ----------------------- |
| `mise run install`    | 依存関係インストール    |
| `mise run test`       | テスト実行              |
| `mise run fmt`        | コードフォーマット      |
| `mise run lint`       | 全 Linter 実行          |
| `mise run pre-commit` | コミット前チェック      |
| `mise run build`      | Nuitka でバイナリビルド |
| `mise run docs`       | ドキュメントビルド      |

## devcontainer CLI + traefik による開発環境 (WSL2)

VS Code を使わず tmux + yazi + claude code などで複数 worktree / 複数プロジェクトを
並行開発する場合は、devcontainer CLI と traefik を組み合わせる方法を使います。
ポート衝突なしに各 devcontainer へ `p<port>.<branch>.<project>.localhost:8080` で
アクセスできます。

### ホスト前提条件

WSL2 ホストに以下が必要です。いずれもユーザーグローバルの mise で管理します
(プロジェクトの `mise.toml` には含まれていません)。

```bash
# Node.js (devcontainer-cli の実行に必要)
mise use --global node@lts

# devcontainer CLI
mise use --global devcontainer-cli@0.86.0
```

`dev:up` 実行時に、ホストで `ssh-agent` と `gpg-agent` が起動していれば
SSH エージェント転送と GPG 署名がコンテナ内で自動的に有効になります。
未起動の場合は起動時に警告が出力されますが、開発は続行できます。

### 初回セットアップ (WSL2 ホストで1回だけ実行)

前提条件のインストール後、以下を実行します。
traefik バイナリの取得・設定・systemd user service への登録を一括で行います。

```bash
mise run traefik:setup
```

traefik の状態確認:

```bash
systemctl --user status traefik
```

### devcontainer の起動と停止

```bash
mise run dev:up      # 現在の worktree の devcontainer を起動
mise run dev:down    # 現在の worktree の devcontainer を停止・削除
mise run dev:exec    # 稼働中の devcontainer に bash で接続
mise run dev:status  # 稼働中の devcontainer 一覧を表示
```

`dev:up` は `devcontainer.json` の `portsAttributes` に定義された全ポートに対して
traefik ルーティングを自動設定します。起動後に以下の形式の URL が表示されます。

```
http://p<port>.<branch>.<project>.localhost:8080
```

例 (ポート `8000`、ブランチ `feature/add-auth`、プロジェクト `boilerplate-python`):

```
http://p8000.feature-add-auth.boilerplate-python.localhost:8080
```

### 複数 worktree での利用

```bash
# 1つ目の worktree
cd /path/to/boilerplate-python
mise run dev:up
# -> http://p8000.main.boilerplate-python.localhost:8080

# 2つ目の worktree (別ブランチ)
cd /path/to/boilerplate-python-feat
mise run dev:up
# -> http://p8000.feature-x.boilerplate-python.localhost:8080
```

ブランチ名は DNS ラベル形式 (小文字英数字とハイフン、63文字以内) に自動変換されます。

## オプションツール

`codeql` など普段使わないツールは `.mise/tools.optional.toml` で管理しています。
必要な時だけ明示的にインストールします:

```bash
mise install --config-file .mise/tools.optional.toml
```

## チュートリアル

[VSCode で極力手を抜いて開発するハンドブック](https://zenn.dev/naa0yama/books/python-boilerplate) を書きました

## Git タグを利用した 動的 Version 付け

GitHub で管理すると tag を付けたらそのバージョンでリリースしたくなる。\
が、通常の方法では `pyproject.toml` の複数 version 箇所を書き換える必要が出る。\
これを回避するため、[pypa/setuptools-scm](https://github.com/pypa/setuptools-scm/tree/main) を利用する。

build 時の設定で [Nuitka](https://github.com/Nuitka/Nuitka) と併用するため `mise run build` にまとめた

## Memo

- 2026-04-26
  - Poetry から `uv` に移行
  - `tox` を廃止し、`mise run` タスクに統一
  - `mise.toml` を導入

- 2025-03-15
  - Poetry 2.x にアップグレード
  - poetry-dynamic-versioning を廃止
  - Nuitka を導入

- 2024-05-09
  - Ruff
    - Linter
    - Formatter
  - Type Checker
    - mypy

- 2024-04-12
  - Linter
    - Markdown
      - Markdown All in One
    - Python
      - Black
      - Python Test Explorer for Visual Studio Code
      - Flake8
      - isort
      - Mypy Type Checker
      - Python
      - Pylance
      - Jupyter
      - autoDocstring
      - Coverage Gutters
    - Json
      - Prettier - Code formatter
    - Yaml
      - YAML
