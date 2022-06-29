from brownie import SVGNFT, config, network
from scripts.helpful_scripts import get_account
from pathlib import Path


def main():
    account = get_account()
    svg_nft = SVGNFT.deploy({"from": account})
    with open("./img/triangle.svg") as f:
        svg = f.read()
    svg_nft.create(svg)
