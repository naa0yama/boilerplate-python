# pythonboilerplate

[![codecov](https://codecov.io/gh/naa0yama/pythonboilerplate/branch/main/graph/badge.svg?token=D8YU7EYIYZ)](https://codecov.io/gh/naa0yama/pythonboilerplate)

Python で開発する時用ボイラープレート

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
