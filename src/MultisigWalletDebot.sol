pragma ton-solidity >= 0.43.0;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./debot-interfaces/Debot.sol";
import "./debot-interfaces/Terminal.sol";
import "./debot-interfaces/Sdk.sol";
import "./debot-interfaces/AddressInput.sol";
import "./debot-interfaces/AmountInput.sol";
import "./debot-interfaces/Upgradable.sol";
import "./debot-interfaces/Menu.sol";
import "./debot-interfaces/SigningBoxInput.sol";
import "./debot-interfaces/ConfirmInput.sol";
import "./debot-interfaces/UserInfo.sol";

import "./interfaces/IMultisig.sol";
import "./interfaces/IStructs.sol";

/* -------------------------------------------------------------------------- */
/*                               ANCHOR Structs                               */
/* -------------------------------------------------------------------------- */

struct UpdateParams {
    uint256 codeHash;
    uint256[] owners;
    uint8 reqConfirms;
}

struct WalletParams {
    uint8 maxQueuedTransactions;
    uint8 maxCustodianCount;
    uint64 expirationTime;
    uint128 minValue;
    uint8 requiredTxnConfirms;
    uint8 requiredUpdConfirms;
}

contract MultisigWalletDebot is Debot, Upgradable, IStructs {
    uint256 _pubkeyMultisig;
    uint32 _keyHandle;

/* -------------------------------------------------------------------------- */
/*                              ANCHOR Variables                              */
/* -------------------------------------------------------------------------- */

    address _targetWallet;

    UpdateParams _updateParams;
    UpdateRequest[] _updates;
    CustodianInfo[] _custodians;
    WalletParams _walletParams;

    uint256 _codeHash;
    TvmCell _walletCode;

    uint8 _requiredVotes;
    UpdateRequest _currentUpdate;

    bool _exist;

/* -------------------------------------------------------------------------- */
/*                              ANCHOR Uploadres                              */
/* -------------------------------------------------------------------------- */

    function setNewCode(TvmCell code) public  {
        tvm.accept();
        _walletCode = code;
        _codeHash = tvm.hash(code);
    }

/* -------------------------------------------------------------------------- */
/*                             ANCHOR constructor                             */
/* -------------------------------------------------------------------------- */

    constructor() public {
        tvm.accept();
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon)
    {
        name = "Update Multisig custodians list";
        version = "0.0.1-beta";
        publisher = "TON Surf";
        key = "";
        author = "TON Surf";
        support = address.makeAddrStd(0, 0x606545c3b681489f2c217782e2da2399b0aed8640ccbcf9884f75648304dbc77);
        hello = "Hello, I’m Multisig Debot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = "";
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, Menu.ID, AddressInput.ID, AmountInput.ID, SigningBoxInput.ID ];
    }

    function start() public override {
        mainMenu();
    }

    function mainMenu() public {
        mainMenuIndex(0);
    }

/* -------------------------------------------------------------------------- */
/*                              ANCHOR Main menu                              */
/* -------------------------------------------------------------------------- */

    function mainMenuIndex(uint32 index) public { index;
        UserInfo.getPublicKey(tvm.functionId(setDefaultPubkey));
        delete _updateParams;
        _exist = true;

        if (_targetWallet == address(0)) {
            MenuItem[] items;
            items.push(MenuItem("Target address", "", tvm.functionId(enterTargetWalletAddress)));
            Menu.select("Please, enter target wallet address", "", items);
        } else {
            delete _currentUpdate;
            getCustodians(0);
            getParameters(0);
            getUpdateRequests(0);
            this.manageMenu();
        }
    }
    function manageMenu() public {
        MenuItem[] items;
        if(_exist) {
            items.push(MenuItem("Show custodians", "", tvm.functionId(showWalletInfo)));
            if(_updates.length > 0) {
                items.push(MenuItem("Sign active submissions", "", tvm.functionId(showSubmissions)));
            }
            items.push(MenuItem("Update custodians", "", tvm.functionId(createSubmissoin)));
        }
        items.push(MenuItem("Change target wallet", "", tvm.functionId(enterTargetWalletAddress)));
        Menu.select("What can I do for you?", "", items);
    }


/* -------------------------------------------------------------------------- */
/*                                ANCHOR enterTargetWalletAddress             */
/* -------------------------------------------------------------------------- */

    function enterTargetWalletAddress(uint32 index) public {
        index;
        AddressInput.get(tvm.functionId(saveTargetAddress), "Enter wallet address");
    }
    function saveTargetAddress(address value) public {
        _targetWallet = value;
        mainMenu();
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR showWalletInfo                       */
/* -------------------------------------------------------------------------- */

    function showWalletInfo(uint32 index) public pure {
        index;
        this.printWalletInfo(0);
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR showSubmissions                      */
/* -------------------------------------------------------------------------- */

    function showSubmissions(uint32 index) public view {
        index;
        getUpdateRequests(0);
        this.showSubmissions1(0);
    }
    function showSubmissions1(uint32 index) public {
        index;
        delete _currentUpdate;
        MenuItem[] items;
        string question;

        for (uint i = 0; i < _updates.length; i++) {
            items.push(MenuItem(format("({}/{})#{}", _updates[i].signs, _requiredVotes, _updates[i].id), "", tvm.functionId(manageSubmission)));
        }
        items.push(MenuItem("Back to main", "", tvm.functionId(mainMenuIndex)));

        if(_updates.length == 0) {
            question = "No submissions";
        } else {
            question = "Select active updates";
        }

        Menu.select(question, "", items);
    }

    function manageSubmission(uint32 index) public {
        _currentUpdate = _updates[index];
        printUpdateRequests(0);

        MenuItem[] items;
        if(_walletParams.requiredUpdConfirms != _currentUpdate.signs) {
            items.push(MenuItem("Confirm submission", "", tvm.functionId(confirmUpdate)));
            items.push(MenuItem("Get instructions for CLI", "", tvm.functionId(confirmUpdate3_2)));
        } else {
            items.push(MenuItem("Execute updating", "", tvm.functionId(executeUpdate)));
            items.push(MenuItem("Get instructions for CLI", "", tvm.functionId(executeUpdate3_2)));
        }
        items.push(MenuItem("Back", "", tvm.functionId(showSubmissions1)));
        Menu.select("What can I do for you?", "", items);
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR confirmUpdate                        */
/* -------------------------------------------------------------------------- */

    function confirmUpdate(uint32 index) public { index;
        _printArrayPubkeys(_currentUpdate.custodians);
        if(_codeHash == _currentUpdate.codeHash) {
            ConfirmInput.get(tvm.functionId(confirmUpdate3), "Agree?");
        } else {
            Terminal.print(0, 'The wallet code is different from the one offered. This debot is not intended for such actions. You should find another way to confirm this submission.');
            showSubmissions(0);
        }
    }
    function confirmUpdate3(bool value) public {
        if(value) {
            confirmUpdate3_1(0);
        } else {
            this.showSubmissions1(0);
        }
    }
    function confirmUpdate3_1(uint32 index) public {
        _printArrayPubkeys(_updateParams.owners);
        index;
        uint[] none;
        SigningBoxInput.get(tvm.functionId(setKeyHandle), "", none);
        this.confirmUpdate4(0);
    }
    function confirmUpdate3_2(uint32 index) public {
        index;
        Terminal.print(0, format("tonos-cli -u https://main.ton.dev call {} confirmUpdate \'{\"updateId\":\"{}\"}\' --abi ./SafeMultisigWallet.abi.json --sign \"{your seed phrase}\"", _targetWallet, _currentUpdate.id));
        Terminal.print(0, "Link to download .abi and .tvc:");
        Terminal.print(0, "(https://github.com/tonlabs/ton-labs-contracts/tree/master/solidity/safemultisig)");
        mainMenu();
    }
    function confirmUpdate4(uint32 index) public view {
        index;
        confirmUpdate5(0);
    }
    function confirmUpdate5(uint32 index) public view {
        index;
        IMultisig(_targetWallet).confirmUpdate{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: _pubkeyMultisig,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(cbConfirmUpdate),
            onErrorId: tvm.functionId(onError),
            signBoxHandle: _keyHandle
        }(_currentUpdate.id);
    }
    function cbConfirmUpdate() public {
        Terminal.print(0, 'Confirming  is done.');
        if(_walletParams.requiredUpdConfirms == _currentUpdate.signs + 1) {
            MenuItem[] items;
            items.push(MenuItem("Execute updating", "", tvm.functionId(executeUpdate)));
            items.push(MenuItem("Get instructions for CLI", "", tvm.functionId(executeUpdate3_2)));
            items.push(MenuItem("Back to main menu", "", tvm.functionId(mainMenuIndex)));
            Menu.select("The number of subscribers is sufficient to complete the update. Do you want to execute? ", "", items);
        } else {
            mainMenu();
        }
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR executeUpdate                        */
/* -------------------------------------------------------------------------- */

    function executeUpdate(uint32 index) public { index;
        _printArrayPubkeys(_currentUpdate.custodians);
        ConfirmInput.get(tvm.functionId(executeUpdate3), "Agree?");
    }
    function executeUpdate3(bool value) public {
        if(value) {
            executeUpdate3_1(0);
        } else {
            this.showSubmissions1(0);
        }
    }
    function executeUpdate3_1(uint32 index) public {
        _printArrayPubkeys(_updateParams.owners);
        index;
        uint[] none;
        SigningBoxInput.get(tvm.functionId(setKeyHandle), "", none);
        this.executeUpdate4(0);
    }
    function executeUpdate3_2(uint32 index) public {
        index;
        Terminal.print(0, format("tonos-cli -u https://main.ton.dev call {} executeUpdate \'{\"updateId\":\"{}\",\"code\":\"{.tvc}\"}\' --abi ./SafeMultisigWallet.abi.json --sign \"{your seed phrase}\"", _targetWallet, _currentUpdate.id));
        Terminal.print(0, "Link to download .abi and .tvc:");
        Terminal.print(0, "(https://github.com/tonlabs/ton-labs-contracts/tree/master/solidity/safemultisig)");
        mainMenu();
    }
    function executeUpdate4(uint32 index) public view {
        index;
        executeUpdate5(0);
    }
    function executeUpdate5(uint32 index) public view {
        index;
        IMultisig(_targetWallet).executeUpdate{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: _pubkeyMultisig,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(cbExecuteUpdate),
            onErrorId: tvm.functionId(onError),
            signBoxHandle: _keyHandle
        }(_currentUpdate.id, _walletCode);
    }
    function cbExecuteUpdate() public {
        Terminal.print(0, 'Executing is done.');
        mainMenu();
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR createSubmissoin                     */
/* -------------------------------------------------------------------------- */

    function createSubmissoin(uint32 index) public {
        index;
        MenuItem[] items;
        items.push(MenuItem("Create submission", "", tvm.functionId(submitUpdate)));
        items.push(MenuItem("Back to main", "", tvm.functionId(mainMenuIndex)));
        Menu.select("What can I do for you?", "", items);
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR submitUpdate                         */
/* -------------------------------------------------------------------------- */

    function submitUpdate(uint32 index) public { index;
        MenuItem[] items;
        _updateParams.codeHash = _codeHash;
        if(_updateParams.reqConfirms == 0) {
            items.push(MenuItem("Enter req confirms", "", tvm.functionId(enterReqConfirms)));
        }
        items.push(MenuItem("Add custodian", "", tvm.functionId(addCustodian)));
        items.push(MenuItem("Back to main", "", tvm.functionId(mainMenuIndex)));
        Menu.select("What else?", "", items);
        this.submitUpdate1();
    }
    function addCustodian(uint32 index) public {
        index;
        Terminal.input(tvm.functionId(setCustodian), "Add custodian pubkey:", false);
    }
    function enterReqConfirms(uint32 index) public {
        index;
        AmountInput.get(tvm.functionId(setReqConfirms), "How many confirmations will be required for transaction?", 0, 1, 32);
    }
    function setCustodian(string value) public {
        (uint256 pubKey, ) = stoi("0x" + value);
        _updateParams.owners.push(pubKey);
    }
    function setReqConfirms(uint128 value) public {
        _updateParams.reqConfirms = uint8(value);
    }

    function submitUpdate1() public pure {
        this.submitUpdate2();
    }
    function submitUpdate2() public {
        Terminal.print(0, 'Let`s check data.');
        Terminal.print(0, format('\nreq confirms: {}', _updateParams.reqConfirms));
        _printArrayPubkeys(_updateParams.owners);
        this.checksubmitUpdate(0);
    }
    function checksubmitUpdate(uint32 index) public {
        index;
        if(
            _updateParams.codeHash != uint256(0) &&
            _updateParams.owners.length != 0 &&
            _updateParams.reqConfirms != 0
        ) {
            ConfirmInput.get(tvm.functionId(submitUpdate3), "Add one more custodian");
        } else {
            this.submitUpdate(0);
        }
    }
    function submitUpdate3(bool value) public {
        if(value) {
            addCustodian(0);
            this.submitUpdate1();
        } else {
            MenuItem[] items;
            items.push(MenuItem("Submit update proposal", "", tvm.functionId(submitUpdate3_1)));
            items.push(MenuItem("Get instructions for CLI", "", tvm.functionId(submitUpdate3_2)));
            items.push(MenuItem("Back to main", "", tvm.functionId(mainMenuIndex)));
            Menu.select("What else?", "", items);
        }
    }
    function submitUpdate3_1(uint32 index) public {
        _printArrayPubkeys(_updateParams.owners);
        index;
        uint[] none;
        SigningBoxInput.get(tvm.functionId(setKeyHandle), "", none);
        this.submitUpdate4(0);
    }
    function submitUpdate3_2(uint32 index) public {
        index;
        Terminal.print(0, format("tonos-cli -u https://main.ton.dev call {} submitUpdate \'{\"codeHash\":{},\"owners\":\"{array of pubkeys}\"},\"reqConfirms\":{amount}}\' --abi ./SafeMultisigWallet.abi.json --sign \"{your seed phrase}\"", _targetWallet, _updateParams.codeHash));
        Terminal.print(0, "Link to download .abi and .tvc:");
        Terminal.print(0, "(https://github.com/tonlabs/ton-labs-contracts/tree/master/solidity/safemultisig)");
        mainMenu();
    }
    function submitUpdate4(uint32 index) public view {
        index;
        submitUpdate5(0);
    }
    function submitUpdate5(uint32 index) public view {
        index;
        IMultisig(_targetWallet).submitUpdate{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: _pubkeyMultisig,
            time: 0,
            expire: 0,
            callbackId: tvm.functionId(cbSubmitUpdate),
            onErrorId: tvm.functionId(onError),
            signBoxHandle: _keyHandle
        }(_updateParams.codeHash, _updateParams.owners, _updateParams.reqConfirms);
    }
    function cbSubmitUpdate(uint64 updateId) public {
        delete _updateParams;
        Terminal.print(0, format('submission Id: {}', updateId));
        mainMenu();
    }

/* -------------------------------------------------------------------------- */
/*                                ANCHOR getUpdateRequests                    */
/* -------------------------------------------------------------------------- */

    function getUpdateRequests(uint32 index) public view { index;
        optional(uint256) none;
        IMultisig(_targetWallet).getUpdateRequests{
            abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(setUpdateRequests),
            onErrorId: tvm.functionId(onErrorWrongSmc),
            time: 0,
            expire: 0,
            sign: false,
            pubkey: none
        }();
    }
    function setUpdateRequests(UpdateRequest[] updates) public {
        _updates = updates;
    }

/* -------------------------------------------------------------------------- */
/*                          ANCHOR     getCustodians                          */
/* -------------------------------------------------------------------------- */

    function getCustodians(uint index) public view { index;
        optional(uint256) none;
        IMultisig(_targetWallet).getCustodians{
            abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(setCustodians),
            onErrorId: tvm.functionId(onErrorWrongSmc),
            time: 0,
            expire: 0,
            sign: false,
            pubkey: none
        }();
    }

    function setCustodians(CustodianInfo[] custodians) public {
        delete _custodians;
        _custodians = custodians;
    }

/* -------------------------------------------------------------------------- */
/*                          ANCHOR     getParameters                          */
/* -------------------------------------------------------------------------- */

    function getParameters(uint index) public view { index;
        optional(uint256) none;
        IMultisig(_targetWallet).getParameters{
            abiVer: 2,
            extMsg: true,
            callbackId: tvm.functionId(setParameters),
            onErrorId: tvm.functionId(onErrorWrongSmc),
            time: 0,
            expire: 0,
            sign: false,
            pubkey: none
        }();
    }
    function setParameters(
        uint8 maxQueuedTransactions,
        uint8 maxCustodianCount,
        uint64 expirationTime,
        uint128 minValue,
        uint8 requiredTxnConfirms,
        uint8 requiredUpdConfirms
    ) public {
        delete _walletParams;
        _walletParams.maxQueuedTransactions = maxQueuedTransactions;
        _walletParams.maxCustodianCount = maxCustodianCount;
        _walletParams.expirationTime = expirationTime;
        _walletParams.minValue = minValue;
        _walletParams.requiredTxnConfirms = requiredTxnConfirms;
        _walletParams.requiredUpdConfirms = requiredUpdConfirms;


        _requiredVotes = (_walletParams.requiredUpdConfirms <= 2) ?
                                _walletParams.requiredUpdConfirms :
                                ((_walletParams.requiredUpdConfirms * 2 + 1) / 3);
    }

/* -------------------------------------------------------------------------- */
/*                              ANCHOR printWalletInfo                        */
/* -------------------------------------------------------------------------- */

    function printWalletInfo(uint32 index) public {
        index;
        Terminal.print(0, format("maxQueuedTransactions: {}\nmaxCustodianCount: {}\nexpirationTime: {}\nminValue: {}\nrequiredTxnConfirms: {}\nrequiredUpdConfirms: {}",
            _walletParams.maxQueuedTransactions,
            _walletParams.maxCustodianCount,
            _walletParams.expirationTime,
            _walletParams.minValue,
            _walletParams.requiredTxnConfirms,
            _walletParams.requiredUpdConfirms
        ));

        for (uint i = 0; i < _custodians.length; i++) {
            string strFromPubkey = format("{:x}", _custodians[i].pubkey);
            strFromPubkey.substr(2);
            Terminal.print(0, (format("Custodian {}: {}", _custodians[i].index + 1, strFromPubkey)));
        }
        mainMenu();
    }

/* -------------------------------------------------------------------------- */
/*                              ANCHOR printUpdateRequests                    */
/* -------------------------------------------------------------------------- */

    function printUpdateRequests(uint32 index) public {
        index;
        Terminal.print(0, format("id: {}\nsigns: {}/{}\ncodeHash: {}\nreqConfirms: {}",
            _currentUpdate.id,
            _currentUpdate.signs,
            _requiredVotes,
            _currentUpdate.codeHash,
            _currentUpdate.reqConfirms
        ));
        _printArrayPubkeys(_currentUpdate.custodians);
    }

/* -------------------------------------------------------------------------- */
/*                               ANCHOR Helpers                               */
/* -------------------------------------------------------------------------- */

    function _printArrayPubkeys(uint256[] custodians) private {
        for (uint i = 0; i < custodians.length; i++) {
            string strFromPubkey = format("{:x}", custodians[i]);
            strFromPubkey.substr(2);
            Terminal.print(0, (format("Custodian {}: {}", i + 1, strFromPubkey)));
        }
    }
    function setKeyHandle(uint32 handle) public {
        _keyHandle = handle;
    }

    function setDefaultPubkey(uint256 value) public {
        _pubkeyMultisig = value;
    }

    function successCb() public {
        mainMenu();
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        Terminal.print(0, format("Sdk error {}. Exit code {}.", sdkError, exitCode));
        mainMenu();
    }

    function onErrorWrongSmc(uint32 sdkError, uint32 exitCode) public {
        if(_exist) {
            Terminal.print(0, format("Unfortunately, this type of wallet is not yet supported. Sdk error {}. Exit code {}.", sdkError, exitCode));
            delete _targetWallet;
            _exist = false;
        }
    }

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
}
