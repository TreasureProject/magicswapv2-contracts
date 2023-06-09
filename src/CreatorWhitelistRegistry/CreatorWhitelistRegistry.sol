// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";


contract CreatorWhitelistRegistry is AccessControl{

    //Create the admin for this creation role.
    bytes32 constant MAGICSWAP_CREATOR_ADMIN_ROLE = keccak256("MAGICSWAP_CREATOR_ADMIN");

    //Create the basic role for creation.
    bytes32 constant MAGICSWAP_CREATOR_ROLE = keccak256("MAGICSWAP_CREATOR");

    //Whether the system should use a creator whitelist.
    bool public useCreatorWhitelistRegistry = true;

    constructor(){
        //Set the magicswap creator admin roles admin to itself, so if you are an admin you can add or remove accounts from being an admin
        _setRoleAdmin(MAGICSWAP_CREATOR_ADMIN_ROLE, MAGICSWAP_CREATOR_ADMIN_ROLE);

        //Set the admin of the creator role to the admin role
        //This means anyone with the admin role can add or remove users from the creation roles
        _setRoleAdmin(MAGICSWAP_CREATOR_ROLE, MAGICSWAP_CREATOR_ADMIN_ROLE);

        //Grant the deployer the admin role
        _grantRole(MAGICSWAP_CREATOR_ADMIN_ROLE, msg.sender);

        //Grant the deployer the creator role
        _grantRole(MAGICSWAP_CREATOR_ROLE, msg.sender);
    }

    function grantCreator(address _user) external onlyRole(MAGICSWAP_CREATOR_ADMIN_ROLE) {
        //Grant the user the creator role
        _grantRole(MAGICSWAP_CREATOR_ROLE, _user);
    }

    function revokeCreator(address _user) external onlyRole(MAGICSWAP_CREATOR_ADMIN_ROLE) {
        //Revoke the user the creator role
        _revokeRole(MAGICSWAP_CREATOR_ROLE, _user);
    }

    function setUseCreatorWhitelistRegistry(bool _useCreatorWhitelistRegistry) external onlyRole(MAGICSWAP_CREATOR_ADMIN_ROLE) {
        useCreatorWhitelistRegistry = _useCreatorWhitelistRegistry;
    }

    function isCreator(address _user) external view returns(bool) {
        return hasRole(MAGICSWAP_CREATOR_ROLE, _user);
    }
}