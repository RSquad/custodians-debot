import { mtrim } from "js-trim-multiline-string";

export const trimlog = (log) => console.log(mtrim(`${log}`));
export const logPubGetter = async (str, smc, functionName) => console.log(`${str}: ${JSON.stringify((await smc.run({ functionName: functionName })).value[functionName], null, 4)}`);

export const sleep = (ms) => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};
