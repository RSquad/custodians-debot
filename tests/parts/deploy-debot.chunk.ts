import { TonClient } from "@tonclient/core";
import pkgMultisigWalletDebot from "../../ton-packages/MultisigWalletDebot.package";
import pkgWallet from "../../ton-packages/SetcodeMultisigWallet.package";
import pkgWalletSurf from "../../ton-packages/SurfMultisigWallet.package";
import { NETWORK_MAP } from "../../utils/client";
import { sendThroughMultisig } from "../../utils/net";
import TonContract from "../../utils/ton-contract";
const fs = require("fs");

export default async (
    client: TonClient,
    smcSafeMultisigWallet: TonContract
) => {
    const keys = await client.crypto.generate_random_sign_keys();

    if (process.env.NETWORK === "MAINNET") {
        fs.writeFileSync("./mainnet-debot-keys.json", JSON.stringify(keys));
    } else {
        fs.writeFileSync("./debot-keys.json", JSON.stringify(keys));
    }

    const smcMultisigWalletDebot = new TonContract({
        client,
        name: "MultisigWalletDebot",
        tonPackage: pkgMultisigWalletDebot,
        keys,
    });
    await smcMultisigWalletDebot.calcAddress();

    await sendThroughMultisig({
        smcSafeMultisigWallet,
        dest: smcMultisigWalletDebot.address,
        value: 2_000_000_000,
    });
    await smcMultisigWalletDebot.deploy();

    await new Promise<void>((resolve) => {
        fs.readFile(
            "./build/MultisigWalletDebot.abi.json",
            "utf8",
            async function (err, data) {
                if (err) {
                    return console.log({ err });
                }
                const buf = Buffer.from(data, "ascii");
                var hexvalue = buf.toString("hex");

                await smcMultisigWalletDebot.call({
                    functionName: "setABI",
                    input: {
                        dabi: hexvalue,
                    },
                });

                resolve();
            }
        );
    });

    await smcMultisigWalletDebot.call({
        functionName: "setCodeWallet",
        input: {
            code: (
                await client.boc.get_code_from_tvc({ tvc: pkgWallet.image })
            ).code,
        },
    });

    await smcMultisigWalletDebot.call({
        functionName: "setCodeWalletSurf",
        input: {
            code: (
                await client.boc.get_code_from_tvc({ tvc: pkgWalletSurf.image })
            ).code,
        },
    });

    console.log(
        `tonos-cli --url ${NETWORK_MAP[process.env.NETWORK]} debot fetch ${
            smcMultisigWalletDebot.address
        }`
    );

    return { smcMultisigWalletDebot };
};
