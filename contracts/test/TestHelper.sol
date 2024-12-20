// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

contract TestHelper is Test {
    function patchUniswapV2Library(address contractUsingUniswapV2Library, string memory contractFilename, bytes memory args)
        public
    {
        bytes memory bytecode = abi.encodePacked(vm.getCode(contractFilename), args);

        bytes32 ORIGINAL_INIT_CODE_HASH = 0x010004df694643e2d7e17535f16c21e9d1698b06c2ef330166830639b23b7f43;
        bytes32 NEW_INIT_CODE_HASH = 0x010004dba4c88c36b9cf5b708cdea396e454c1d162b487daa289669537fe8f0d;

        // bytecode = contractUsingUniswapV2Library.code;
        bytecode = veryBadBytesReplacer(bytecode, ORIGINAL_INIT_CODE_HASH, NEW_INIT_CODE_HASH);
        vm.etch(contractUsingUniswapV2Library, bytecode);
    }

    /**
     * @dev Non-optimised code to replace a certain 32 bytes sequence in a longer bytes object.
     * @dev Assumes the 32 bytes sequence is exactly once present in the bytes object.
     * Reverts if it is not present and only replaces first occurrence if present multiple times.
     */
    function veryBadBytesReplacer(bytes memory bytecode, bytes32 target, bytes32 replacement)
        internal
        pure
        returns (bytes memory result)
    {
        result = veryBadBytesReplacer(bytecode, abi.encodePacked(target), abi.encodePacked(replacement));
    }

    function veryBadBytesReplacer(bytes memory bytecode, bytes memory target, bytes memory replacement)
        internal
        pure
        returns (bytes memory result)
    {
        require(target.length <= bytecode.length);
        require(target.length == replacement.length);

        uint256 lengthTarget = target.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        uint256 i;
        for (i; i < lengthBytecode;) {
            uint256 j = 0;
            for (j; j < lengthTarget;) {
                if (bytecode[i + j] == target[j]) {
                    if (j == lengthTarget - 1) {
                        // Target found, replace with replacement, and return result.
                        return result = replaceBytes(bytecode, replacement, i);
                    }
                } else {
                    break;
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
        // Should always find one single match. -> revert if not.
        revert();
    }

    function veryBadBytesReplacer(
        bytes memory bytecode,
        bytes memory target,
        bytes memory replacement,
        bool replaceFirstOnly
    ) internal pure returns (bytes memory) {
        require(target.length <= bytecode.length);
        require(target.length == replacement.length);

        uint256 lengthTarget = target.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        for (uint256 i; i < lengthBytecode; ++i) {
            uint256 j = 0;
            for (j; j < lengthTarget; ++j) {
                if (bytecode[i + j] == target[j]) {
                    if (j == lengthTarget - 1) {
                        // Target found, replace with replacement.
                        bytecode = replaceBytes(bytecode, replacement, i);
                        if (replaceFirstOnly) return bytecode;
                    }
                } else {
                    break;
                }
            }
        }
        return bytecode;
    }

    /**
     * @dev Reverts if startPosition + replacement.length is bigger than bytecode.length.
     */
    function replaceBytes(bytes memory bytecode, bytes memory replacement, uint256 startPosition)
        internal
        pure
        returns (bytes memory)
    {
        uint256 lengthReplacement = replacement.length;
        for (uint256 j; j < lengthReplacement;) {
            bytecode[startPosition + j] = replacement[j];

            unchecked {
                ++j;
            }
        }
        return bytecode;
    }
}
