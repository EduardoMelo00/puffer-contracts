// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @title PufferVaultStorage
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
abstract contract PufferVaultStorage {
    /**
     * @custom:storage-location erc7201:puffervault.storage
     * @dev +-----------------------------------------------------------+
     *      |                                                           |
     *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
     *      |                                                           |
     *      +-----------------------------------------------------------+
     */
    struct VaultStorage {
        // 6 Slots for Redemption logic
        uint256 lidoLockedETH;
        uint256 eigenLayerPendingWithdrawalSharesAmount;
        bool isLidoWithdrawal; // Not in use in PufferVaultV2
        EnumerableSet.UintSet lidoWithdrawals; // Not in use in PufferVaultV2
        EnumerableSet.Bytes32Set eigenLayerWithdrawals;
        EnumerableMap.UintToUintMap lidoWithdrawalAmounts;
        // 1 Slot for daily withdrawal limits
        uint96 dailyAssetsWithdrawalLimit;
        uint96 assetsWithdrawnToday;
        uint64 lastWithdrawalDay;
        // 1 slot for withdrawal fee
        uint256 exitFeeBasisPoints;
        // ETH rewards amount
        uint256 totalRewardDepositAmount;
        uint256 totalRewardMintAmount;
        //  Grants Fields (V3)
        uint256 maxGrantAmount;
        address grantManager;
        mapping(address => bool) approvedGrantRecipients;
        mapping(address => bool) prefersWETH;
    }

    // keccak256(abi.encode(uint256(keccak256("puffervault.depositTracker")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _DEPOSIT_TRACKER_LOCATION =
        0x78b7b410d94d33094d5b8a71f1c003e2cbb9e212054d2df1984e3dabc3b25e00;

    // keccak256(abi.encode(uint256(keccak256("puffervault.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _VAULT_STORAGE_LOCATION =
        0x611ea165ca9257827fc43d2954fdae7d825e82c825d9037db9337fa1bfa93100;

    function _getPufferVaultStorage()
        internal
        pure
        returns (VaultStorage storage $)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _VAULT_STORAGE_LOCATION
        }
    }
}
