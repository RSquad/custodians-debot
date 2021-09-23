import TonContract from "../../utils/ton-contract";

export default async (smcWallet: TonContract) => {
    await smcWallet.call({
        functionName: "submitUpdate",
        input: {
            codeHash: `0x${process.env.CODE_HASH}`,
            owners: [
                `0x${process.env.OWNER_PUBKEY}`,
                `0x${process.env.ANOTHER_OWNER_PUBKEY}`,
            ],
            reqConfirms: 2,
        },
        keys: {
            public: process.env.ANOTHER_OWNER_PUBKEY,
            secret: process.env.ANOTHER_OWNER_SECRET,
        },
    });
};
