from brownie import RandomSVG, config, network
from scripts.helpful_scripts import get_account
import time


def main():
    account = get_account()
    if len(RandomSVG) > 0:
        random_svg = RandomSVG[-1]
    else:
        random_svg = RandomSVG.deploy(
            config["networks"][network.show_active()]["coordinator_sub_id"],
            config["networks"][network.show_active()]["vrf_coordinator"],
            {"from": account},
            publish_source=True,
        )
    token_counter = random_svg.tokenCounter()
    tx = random_svg.create({"from": account})
    tx.wait(1)
    time.sleep(90)
    random_svg.completeMint(token_counter, {"from": account})

    # random_svg = RandomSVG.deploy(
    #     config["networks"][network.show_active()]["coordinator_sub_id"],
    #     config["networks"][network.show_active()]["vrf_coordinator"],
    #     {"from": account},
    #     publish_source=True,
    # )
