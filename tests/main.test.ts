import { TonClient } from "@tonclient/core";
import pkgSafeMultisigWallet from "../ton-packages/SafeMultisigWallet.package";
import { createClient } from "../utils/client";
import TonContract from "../utils/ton-contract";
import createSubmissionChunk from "./parts/create-submission.chunk";
import deployDebotChunk from "./parts/deploy-debot.chunk";
import deployWalletChunk from "./parts/deploy-wallet.chunk";

describe("debot test", () => {
    let client: TonClient;
    let smcSafeMultisigWallet: TonContract;
    let smcWallet: TonContract;
    let smcMultisigWalletDebot: TonContract;

    before(async () => {
        client = createClient();
        smcSafeMultisigWallet = new TonContract({
            client,
            name: "SafeMultisigWallet",
            tonPackage: pkgSafeMultisigWallet,
            address: process.env.MULTISIG_ADDRESS,
            keys: {
                public: process.env.MULTISIG_PUBKEY,
                secret: process.env.MULTISIG_SECRET,
            },
        });
    });

    it("deploy debot", async () => {
        const result = await deployDebotChunk(client, smcSafeMultisigWallet);
        smcMultisigWalletDebot = result.smcMultisigWalletDebot;
        console.log("debotAddr");
        console.log(smcMultisigWalletDebot.address);
    });

    it("deploy wallet", async () => {
        const result = await deployWalletChunk(client, smcSafeMultisigWallet);
        smcWallet = result.smcWallet;
        console.log("walletAddr", smcWallet.address);
    });
    it("create submission for update", async () => {
        await createSubmissionChunk(smcWallet);
    });
});
