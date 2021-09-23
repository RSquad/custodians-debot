
pragma ton-solidity >= 0.43;

struct UpdateRequest {
    // request id
    uint64 id;
    // index of custodian submitted request
    uint8 index;
    // number of confirmations from custodians
    uint8 signs;
    // confirmation binary mask
    uint32 confirmationsMask;
    // public key of custodian submitted request
    uint256 creator;
    // hash from code's tree of cells
    uint256 codeHash;
    // array with new wallet custodians
    uint256[] custodians;
    // Default number of confirmations required to execute transaction
    uint8 reqConfirms;
}

struct CustodianInfo {
    uint8 index;
    uint256 pubkey;
}

interface IStructs {
}
