const fs = require("fs");
const shell = require("shelljs");
const sha256 = require("js-sha256");

if (!shell.which("git")) {
    shell.echo("Sorry, this script requires git");
    shell.exit(1);
}

const smcNames = ["MultisigWalletDebot"];

// const rawSmcHashes = fs.readFileSync(`./.build-hashes`);
// const smcHashes = JSON.parse(rawSmcHashes);
const smcHashes = {};

const compileScripts = [];

smcNames.forEach((name) => {
    const raw = fs.readFileSync(`./src/${name}.sol`);
    const hash = sha256(raw);
    if (hash !== smcHashes[name]) {
        smcHashes[name] = hash;
        compileScripts.push(`npx tondev sol compile ./src/${name}.sol`);
        compileScripts.push(
            `mv ./src/${name}.abi.json ./build/${name}.abi.json`
        );
        compileScripts.push(`mv ./src/${name}.tvc ./build/${name}.tvc`);
    }
});

compileScripts.forEach((script) => {
    shell.exec(script);
});

smcNames.forEach((name) => {
    const abiRaw = fs.readFileSync(`./build/${name}.abi.json`);
    const abi = JSON.parse(abiRaw);
    const image = fs.readFileSync(`./build/${name}.tvc`, {
        encoding: "base64",
    });

    fs.writeFileSync(
        `./ton-packages/${name}.package.ts`,
        `export default ${JSON.stringify({ abi, image })}`
    );
});

// fs.writeFileSync(`./.build-hashes`, `${JSON.stringify(smcHashes)}`);

shell.exit(0);
