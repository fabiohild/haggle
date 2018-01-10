pragma solidity ^0.4.18;

/// @title ERC20 interface
contract ERC20 {
    function balanceOf(address guy) public view returns (uint);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(
        address src, address dst, uint wad
    ) public returns (bool);
}

/// @title Manages access privileges.
contract AccessControl is ERC20 {

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    mapping(address => mapping(string => bool)) accessRights;

    // @dev Keeps track whether the contract is paused. When that is true, most actions are blocked
    bool public paused = false;

    /// @dev Grants access to accessManagement to deployer of the contract
    function AccessControl() public {
        accessRights[msg.sender]["accessManagement"] = true;
    }

    /// @dev Provides access to a determined transaction
    /// @param _user - user that will be granted the access right
    /// @param _transaction - transaction that will be granted to user
    function grantAccess(address _user, string _transaction) public canAccess("accessManagement") {
        require(_user != address(0));
        accessRights[_user][_transaction] = true;
    }

    /// @dev Revokes access to a determined transaction
    /// @param _user - user that will have the access revoked
    /// @param _transaction - transaction that will be revoked
    function revokeAccess(address _user, string _transaction) public canAccess("accessManagement") {
        require(_user != address(0));
        accessRights[_user][_transaction] = false;
    }

    /// @dev Check if user has access to a determined transaction
    /// @param _user - user
    /// @param _transaction - transaction
    function hasAccess(address _user, string _transaction) public view canAccess("accessManagement") returns (bool) {
        require(_user != address(0));
        return accessRights[_user][_transaction];
    }

    /// @dev Access modifier
    /// @param _transaction - transaction
    modifier canAccess(string _transaction) {
        require(accessRights[msg.sender][_transaction]);
        _;
    }

    /// @dev Drains all Eth
    function withdrawBalance() external canAccess("balanceManagement") {
        msg.sender.transfer(this.balance);
    }

    /// @dev Drains any ERC20 token accidentally sent to contract
    function withdrawTokens(address _tokenContract) external canAccess("balanceManagement") {
        ERC20 tc = ERC20(_tokenContract);
        tc.transfer(msg.sender, tc.balanceOf(this));
    }

    /// @dev Modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /// @dev Modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused);
        _;
    }

    /// @dev Called by any "C-level" role to pause the contract. Used only when
    ///  a bug or exploit is detected and we need to limit damage.
    function pause() public canAccess("pause") whenNotPaused {
        paused = true;
    }

    /// @dev Unpauses the smart contract.
    function unpause() public canAccess("unpause") whenPaused {
        paused = false;
    }
}
