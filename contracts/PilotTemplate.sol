pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-token-manager/contracts/HookedTokenManager.sol";
import {IConvictionVoting as ConvictionVoting} from "./external/IConvictionVoting.sol";


contract PilotTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "MISSING_MEMBERS";
    string constant private ERROR_NO_CACHE = "NO_CACHE";

    //
    // bytes32 private constant DANDELION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("gardens-dandelion-voting")));
    bytes32 private constant CONVICTION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("conviction-beta")));
    bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("gardens-token-manager")));
    // bytes32 private constant ISSUANCE_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("issuance")));
    // bytes32 private constant TOLLGATE_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("tollgate")));

    // xdai
    // bytes32 private constant CONVICTION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("1hive"), keccak256("conviction-voting")));
    // bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = keccak256(abi.encodePacked(apmNamehash("1hive"), keccak256("token-manager")));


    uint8 private constant TOKEN_DECIMALS = uint8(18);
    uint256 private constant TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    address private constant ANY_ENTITY = address(-1);
    uint8 private constant ORACLE_PARAM_ID = 203;
    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, RET, NOT, AND, OR, XOR, IF_ELSE }


    constructor(DAOFactory _daoFactory, ENS _ens, MiniMeTokenFactory _miniMeFactory, IFIFSResolvingRegistrar _aragonID)
        BaseTemplate(_daoFactory, _ens, _miniMeFactory, _aragonID)
        public
    {
        _ensureAragonIdIsValid(_aragonID);
        _ensureMiniMeFactoryIsValid(_miniMeFactory);
    }

    // New DAO functions //

    /**
    * @dev Create the DAO and initialise the basic apps necessary for gardens
    * @param _referenceToken MiniMe Token used for funding and as reference for non-transferrable reputation
    * @param _snapshotBlock uint block height for snapshoting voting influence from referenceToken
    * @param _admin address of the account which will have admin rights
    * @param _convictionSettings array of conviction initialization params

    */
    function createDaoTxOne(
        MiniMeToken _referenceToken,
        uint _snapshotBlock,
        address _admin,
        uint64[4] _convictionSettings
    )
        public
    {

        (Kernel dao, ACL acl) = _createDAO();
        Vault fundingPoolVault = _installVaultApp(dao);

        _createEvmScriptsRegistryPermissions(acl, _admin, _admin);
        MiniMeToken voteToken = _referenceToken.createCloneToken(
          "Conviction",
          18,
          "CVTN",
          _snapshotBlock,
          false
          );

        HookedTokenManager hookedTokenManager = _installHookedTokenManagerApp(dao, voteToken, false, TOKEN_MAX_PER_ACCOUNT);
        _createHookedTokenManagerPermissions(acl, _admin, hookedTokenManager);

        ConvictionVoting convictionVoting = _installConvictionVoting(dao, voteToken, fundingPoolVault, address(_referenceToken), _convictionSettings);

        address[] memory grantees = new address[](2);
        grantees[0] = address(convictionVoting);
        grantees[1] = address(_admin);
        _createPermissions(acl, grantees, fundingPoolVault, fundingPoolVault.TRANSFER_ROLE(), _admin);

        _createConvictionVotingPermissions(acl, convictionVoting, _admin);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, _admin);
    }

    function _installHookedTokenManagerApp(
        Kernel _dao,
        MiniMeToken _token,
        bool _transferable,
        uint256 _maxAccountTokens
    )
        internal returns (HookedTokenManager)
    {
        HookedTokenManager hookedTokenManager = HookedTokenManager(_installDefaultApp(_dao, HOOKED_TOKEN_MANAGER_APP_ID));
        _token.changeController(hookedTokenManager);
        hookedTokenManager.initialize(_token, _transferable, _maxAccountTokens);
        return hookedTokenManager;
    }

    function _createHookedTokenManagerPermissions(ACL acl, address _admin,HookedTokenManager hookedTokenManager) internal {

        acl.createPermission(_admin, hookedTokenManager, hookedTokenManager.MINT_ROLE(), _admin);
        acl.createPermission(_admin, hookedTokenManager, hookedTokenManager.BURN_ROLE(), _admin);

    }

    function _installConvictionVoting(Kernel _dao, MiniMeToken _stakeToken, Vault _agentOrVault, address _requestToken, uint64[4] _convictionSettings)
        internal returns (ConvictionVoting)
    {
        ConvictionVoting convictionVoting = ConvictionVoting(_installNonDefaultApp(_dao, CONVICTION_VOTING_APP_ID));
        convictionVoting.initialize(_stakeToken, _agentOrVault, _requestToken, _convictionSettings[0], _convictionSettings[1], _convictionSettings[2], _convictionSettings[3]);
        return convictionVoting;
    }

    // Permission setting functions //

    function _createConvictionVotingPermissions(ACL _acl, ConvictionVoting _convictionVoting, address _manager)
        internal
    {
        _acl.createPermission(ANY_ENTITY, _convictionVoting, _convictionVoting.CREATE_PROPOSALS_ROLE(), _manager);
    }

    // Oracle permissions with params functions //

    function _setOracle(ACL _acl, address _who, address _where, bytes32 _what, address _oracle) private {
        uint256[] memory params = new uint256[](1);
        params[0] = _paramsTo256(ORACLE_PARAM_ID, uint8(Op.EQ), uint240(_oracle));

        _acl.grantPermissionP(_who, _where, _what, params);
    }

    function _paramsTo256(uint8 _id,uint8 _op, uint240 _value) private returns (uint256) {
        return (uint256(_id) << 248) + (uint256(_op) << 240) + _value;
    }
}
