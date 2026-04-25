#!/usr/bin/env python3
# To add a new cell, type '# %%'
# To add a new markdown cell, type '# %% [markdown]'
# %%
"""test pyproject.toml."""

from pathlib import Path

from tomllib import load


def test_pyproj() -> None:
    """Test if NAME matches in pyproject.toml."""
    with Path(f"{Path(__file__).parent.parent}/pyproject.toml").open("rb") as __stream:
        __config: dict = load(__stream)

    """project name."""
    assert (
        f"{__config['project']['name']}.cli:main" == __config["project"]["scripts"]["sample-cli"]
    )
    assert (
        f"src/{__config['project']['name']}"
        == __config["tool"]["sphinx-pyproject"]["package_root"]
    )
    assert __config["project"]["name"] == __config["tool"]["sphinx-pyproject"]["project"]
