import { TonClient } from "@tonclient/core";
import pkgWallet from "../../ton-packages/SetcodeMultisigWallet.package";
import { sendThroughMultisig } from "../../utils/net";
import TonContract from "../../utils/ton-contract";

export default async (
    client: TonClient,
    smcSafeMultisigWallet: TonContract
) => {
    const keys = await client.crypto.generate_random_sign_keys();
    const smcWallet = new TonContract({
        client,
        name: "Wallet",
        tonPackage: pkgWallet,
        keys,
    });
    await smcWallet.calcAddress();

    await sendThroughMultisig({
        smcSafeMultisigWallet,
        dest: smcWallet.address,
        value: 10_000_000_000,
    });

    await smcWallet.deploy({
        input: {
            owners: [
                `0x${process.env.OWNER_PUBKEY}`,
                `0x${process.env.ANOTHER_OWNER_PUBKEY}`,
            ],
            reqConfirms: 1,
        },
    });

    return { smcWallet };
};
