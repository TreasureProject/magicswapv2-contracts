// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


interface ICreatorWhitelistRegistry {

    function isCreator(address _user) external view returns(bool);

    function useCreatorWhitelistRegistry() external view returns(bool);
}