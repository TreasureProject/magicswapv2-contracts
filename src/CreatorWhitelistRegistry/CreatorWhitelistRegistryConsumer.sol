// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


import "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import  "./ICreatorWhitelistRegistry.sol";

contract CreatorWhitelistRegistryConsumer is Ownable {
    ICreatorWhitelistRegistry creatorWhitelistRegistry;

    /// @dev Sets the creator whitelist registry address.
    /// @param _creatorWhitelistRegistryAddress The address of the registry.
    function setCreatorWhitelistRegistryAddress(address _creatorWhitelistRegistryAddress) external onlyOwner{
        creatorWhitelistRegistry = ICreatorWhitelistRegistry(_creatorWhitelistRegistryAddress);
    }
}