# pythonboilerplate

![coverage](https://raw.githubusercontent.com/naa0yama/boilerplate-python/badges/coverage.svg)
![test execution time](https://raw.githubusercontent.com/naa0yama/boilerplate-python/badges/time.svg)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![mise](https://img.shields.io/badge/mise-enabled-blue)](https://mise.jdx.dev)
[![Python](https://img.shields.io/badge/python-3.12-blue)](https://www.python.org)

Python で開発する時用ボイラープレート

## Getting Started

`mise` でツール一式 (Python, uv, dprint など) をプロビジョニングし、 `uv` で依存関係をインストールする。

```bash
# mise のインストール (未導入の場合)
# https://mise.jdx.dev/getting-started.html
curl https://mise.run | sh

# ツール一式のインストール (Python 3.12, uv, dprint, actionlint, ...)
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
