pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";
import "@1hive/apps-token-manager/contracts/HookedTokenManager.sol";
import "@1hive/apps-redemptions/contracts/Redemptions.sol";
import {IConvictionVoting as ConvictionVoting} from "./external/IConvictionVoting.sol";


contract PilotTemplate is BaseTemplate {

    string constant private ERROR_MISSING_MEMBERS = "MISSING_MEMBERS";
    string constant private ERROR_NO_CACHE = "NO_CACHE";

    //
    bytes32 private constant CONVICTION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("conviction-beta")));
    bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("gardens-token-manager")));
    bytes32 private constant REDEMPTIONS_APP_ID = apmNamehash("redemptions");


    // xdai
    // bytes32 private constant CONVICTION_VOTING_APP_ID = keccak256(abi.encodePacked(apmNamehash("1hive"), keccak256("conviction-voting")));
    // bytes32 private constant HOOKED_TOKEN_MANAGER_APP_ID = keccak256(abi.encodePacked(apmNamehash("1hive"), keccak256("token-manager")));


    uint8 private constant TOKEN_DECIMALS = uint8(18);
    uint256 private constant TOKEN_MAX_PER_ACCOUNT = uint256(-1);
    address private constant ANY_ENTITY = address(-1);
    uint8 private constant ORACLE_PARAM_ID = 203;
    enum Op { NONE, EQ, NEQ, GT, LT, GTE, LTE, RET, NOT, AND, OR, XOR, IF_ELSE }

    struct DeployedContracts {
        Kernel dao;
        ACL acl;
        Vault fundingPoolVault;
        MiniMeToken referenceToken;
        ConvictionVoting convictionVoting;
        MiniMeToken aaant;
        HookedTokenManager aaantManager;
    }

    mapping(address => DeployedContracts) internal senderDeployedContracts;

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
        uint256[4] _convictionSettings
    )
        public
    {

        (Kernel dao, ACL acl) = _createDAO();
        Vault fundingPoolVault = _installVaultApp(dao);

        _createEvmScriptsRegistryPermissions(acl, _admin, _admin);
        MiniMeToken voteToken = _referenceToken.createCloneToken(
          "Snapshot ANT",
          18,
          "sANT",
          _snapshotBlock,
          false
          );

        HookedTokenManager hookedTokenManager = _installHookedTokenManagerApp(dao, voteToken, false, TOKEN_MAX_PER_ACCOUNT);
        _createHookedTokenManagerPermissions(acl, _admin, hookedTokenManager);

        MiniMeToken aaant = _createToken("Aragon Association Wrapped ANT", "AA-ANT", 18);
        HookedTokenManager aaantManager = _installHookedTokenManagerApp(dao, aaant, true, TOKEN_MAX_PER_ACCOUNT);
        _createHookedTokenManagerPermissions(acl, _admin, aaantManager);

        ConvictionVoting convictionVoting = _installConvictionVoting(dao, voteToken, fundingPoolVault, address(aaant), _convictionSettings);

        _storeDeployedContractsTxOne(dao, acl, fundingPoolVault, _referenceToken, convictionVoting, aaant, aaantManager);
    }

    /**
    * @dev Create the DAO and initialise the basic apps necessary for gardens
    * @param _admin address of the account which will have admin rights
    */
    function createDaoTxTwo(
      address _admin
      )
        public
      {
        (Kernel dao,
        ACL acl,
        Vault fundingPoolVault,
        MiniMeToken referenceToken,
        ConvictionVoting convictionVoting,
        MiniMeToken aaant,
        HookedTokenManager aaantManager) = _getDeployedContractsTxOne();



        address[] memory redeemableTokens = new address[](1);
        redeemableTokens[0] = address(referenceToken);

        Redemptions redemptions = _installRedemptions(dao, fundingPoolVault, aaantManager, redeemableTokens);
        _createRedemptionsPermissions(acl, redemptions, _admin);

        address[] memory grantees = new address[](3);
        grantees[0] = address(convictionVoting);
        grantees[1] = address(_admin);
        grantees[2] = address(redemptions);
        _createPermissions(acl, grantees, fundingPoolVault, fundingPoolVault.TRANSFER_ROLE(), _admin);

        _createConvictionVotingPermissions(acl, convictionVoting, _admin);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, _admin);

        _deleteStoredContracts();

      }

      //   _storeDeployedContractsTxOne(dao, acl, fundingPoolVault, _referenceToken, voteToken, hookedTokenManager, aaant, aaantManager)
      function _storeDeployedContractsTxOne(Kernel _dao, ACL _acl, Vault _agentOrVault, MiniMeToken _referenceToken, ConvictionVoting _convictionVoting, MiniMeToken _aaant, HookedTokenManager _aaantManager)
          internal
      {
          DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
          deployedContracts.dao = _dao;
          deployedContracts.acl = _acl;
          deployedContracts.fundingPoolVault = _agentOrVault;
          deployedContracts.referenceToken = _referenceToken;
          deployedContracts.convictionVoting = _convictionVoting;
          deployedContracts.aaant = _aaant;
          deployedContracts.aaantManager = _aaantManager;
      }

      function _getDeployedContractsTxOne() internal returns (Kernel, ACL, Vault, MiniMeToken, ConvictionVoting, MiniMeToken, HookedTokenManager) {
          DeployedContracts storage deployedContracts = senderDeployedContracts[msg.sender];
          return (
            deployedContracts.dao,
            deployedContracts.acl,
            deployedContracts.fundingPoolVault,
            deployedContracts.referenceToken,
            deployedContracts.convictionVoting,
            deployedContracts.aaant,
            deployedContracts.aaantManager
          );
      }

      function _deleteStoredContracts() internal {
          delete senderDeployedContracts[msg.sender];
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

    function _installRedemptions(Kernel _dao, Vault _agentOrVault, HookedTokenManager _hookedTokenManager, address[] _redeemableTokens)
        internal returns (Redemptions)
    {
        Redemptions redemptions = Redemptions(_installNonDefaultApp(_dao, REDEMPTIONS_APP_ID));
        redemptions.initialize(_agentOrVault, TokenManager(_hookedTokenManager), _redeemableTokens);
        return redemptions;
    }

    function _createRedemptionsPermissions(ACL _acl, Redemptions _redemptions, address _admin)
        internal
    {
        _acl.createPermission(_admin, _redemptions, _redemptions.REDEEM_ROLE(), _admin);
        _acl.createPermission(_admin, _redemptions, _redemptions.ADD_TOKEN_ROLE(), _admin);
        _acl.createPermission(_admin, _redemptions, _redemptions.REMOVE_TOKEN_ROLE(), _admin);
    }

    function _installConvictionVoting(Kernel _dao, MiniMeToken _stakeToken, Vault _agentOrVault, address _requestToken, uint256[4] _convictionSettings)
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
