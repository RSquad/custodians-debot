pragma ton-solidity >= 0.43;

import "./IStructs.sol";

interface IMultisig {
    function submitTransaction(
        address dest,
        uint128 value,
        bool bounce,
        bool allBalance,
        TvmCell payload)
    external returns (uint64 transId);

    function sendTransaction(
        address dest,
        uint128 value,
        bool bounce,
        uint8 flags,
        TvmCell payload)
    external;

// update
    function submitUpdate(
        uint256 codeHash,
        uint256[] owners,
        uint8 reqConfirms)
    external returns (uint64 updateId);

    function confirmUpdate(uint64 updateId) external;
    function executeUpdate(uint64 updateId, TvmCell code) external;

//getters
    function getUpdateRequests() external view returns (UpdateRequest[] updates);
    function getCustodians() external view returns (CustodianInfo[] custodians);
    function getParameters() external view returns (
        uint8 maxQueuedTransactions,
        uint8 maxCustodianCount,
        uint64 expirationTime,
        uint128 minValue,
        uint8 requiredTxnConfirms,
        uint8 requiredUpdConfirms);
}
