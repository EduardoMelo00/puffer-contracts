// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {PufferVaultV3} from "./PufferVaultV3.sol";
import {IStETH} from "./interface/Lido/IStETH.sol";
import {ILidoWithdrawalQueue} from "./interface/Lido/ILidoWithdrawalQueue.sol";
import {IEigenLayer} from "./interface/EigenLayer/IEigenLayer.sol";
import {IStrategy} from "./interface/EigenLayer/IStrategy.sol";
import {IDelegationManager} from "./interface/EigenLayer/IDelegationManager.sol";
import {IWETH} from "./interface/Other/IWETH.sol";
import {IPufferOracle} from "./interface/IPufferOracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PufferVaultV3_Grant
 * @dev Implementation of the PufferVault contract that includes:
 *      - a grant payment system with settable WETH/ETH preference by recipients.
 * @custom:security-contact security@puffer.fi
 */
contract PufferVaultV3_Grant is PufferVaultV3 {
    using Math for uint256;

    error NotAuthorizedGrantManager();
    error NotApprovedRecipient(address recipient);
    error AmountExceedsMaxGrant(uint256 requested, uint256 maxGrant);
    error NotEnoughWETHToUnwrap(uint256 neededWETH);
    error WETHDepositFailed();
    error WETHTransferFailed();

    event GrantManagerUpdated(
        address indexed oldManager,
        address indexed newManager
    );
    event GrantRecipientApproval(address indexed recipient, bool approved);
    event MaxGrantAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event GrantPaid(address indexed recipient, uint256 amount, bool inWETH);

    /**
     * @notice Initializes the contract (V4 style).
     * @param stETH Address of the stETH token contract.
     * @param weth Address of the WETH token contract.
     * @param lidoWithdrawalQueue Address of the Lido withdrawal queue contract.
     * @param stETHStrategy Address of the stETH strategy contract.
     * @param eigenStrategyManager Address of the EigenLayer strategy manager contract.
     * @param oracle Address of the PufferOracle contract.
     * @param delegationManager Address of the delegation manager contract.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(
        IStETH stETH,
        IWETH weth,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager,
        IPufferOracle oracle,
        IDelegationManager delegationManager
    )
        PufferVaultV3(
            stETH,
            weth,
            lidoWithdrawalQueue,
            stETHStrategy,
            eigenStrategyManager,
            oracle,
            delegationManager
        )
    {
        // Prevent anyone from calling .initialize() on this implementation contract directly
        _disableInitializers();
    }

    // ==================================================
    // =============== GRANT PAYMENT SYSTEM =============
    // ==================================================

    /**
     * @dev Modifier restricting access to the current `grantManager`.
     */
    modifier onlyGrantManager() {
        VaultStorage storage $ = _getPufferVaultStorage();
        if (msg.sender != $.grantManager) {
            revert NotAuthorizedGrantManager();
        }
        _;
    }

    /**
     * @notice Sets the address of the grant manager.
     * @dev Only callable by an account with the `restricted` role.
     */
    function setGrantManager(address newManager) external restricted {
        VaultStorage storage $ = _getPufferVaultStorage();
        address oldManager = $.grantManager;
        $.grantManager = newManager;

        emit GrantManagerUpdated(oldManager, newManager);
    }

    /**
     * @notice Sets the maximum amount that can be sent in a single grant.
     * @dev Only callable by the current grant manager.
     */
    function setMaxGrantAmount(
        uint256 newMaxGrantAmount
    ) external onlyGrantManager {
        VaultStorage storage $ = _getPufferVaultStorage();
        uint256 oldAmount = $.maxGrantAmount;
        $.maxGrantAmount = newMaxGrantAmount;

        emit MaxGrantAmountUpdated(oldAmount, newMaxGrantAmount);
    }

    /**
     * @notice Approves or revokes approval for an address to receive grants.
     * @dev Only callable by the current grant manager.
     */
    function approveGrantRecipient(
        address recipient,
        bool approved
    ) external onlyGrantManager {
        VaultStorage storage $ = _getPufferVaultStorage();
        $.approvedGrantRecipients[recipient] = approved;

        emit GrantRecipientApproval(recipient, approved);
    }

    /**
     * @notice Returns whether a given recipient is approved to receive grants.
     * @param recipient The address to check.
     * @return True if the recipient is approved, false otherwise.
     */
    function isApprovedGrantRecipient(
        address recipient
    ) external view returns (bool) {
        VaultStorage storage $ = _getPufferVaultStorage();
        return $.approvedGrantRecipients[recipient];
    }

    /**
     * @notice Allows an approved recipient to set their preference to receive grants in WETH or ETH.
     * @dev Reverts if `msg.sender` is not approved as a grant recipient.
     * @param inWETH If true, the user is paid in WETH; otherwise in ETH.
     */
    function setGrantPaymentPreference(bool inWETH) external {
        VaultStorage storage $ = _getPufferVaultStorage();
        if (!$.approvedGrantRecipients[msg.sender]) {
            revert NotApprovedRecipient(msg.sender);
        }
        $.prefersWETH[msg.sender] = inWETH;
    }

    /**
     * @notice Pays out a grant to an approved recipient, respecting their stored preference (ETH or WETH).
     * @dev Only callable by the current grant manager. The vault must hold enough ETH or WETH (can unwrap if needed).
     * @param recipient The address receiving the grant (must be previously approved).
     * @param amount The amount of the grant, in wei.
     */
    function payGrant(
        address recipient,
        uint256 amount
    ) external onlyGrantManager {
        VaultStorage storage $ = _getPufferVaultStorage();

        // Check if the recipient is approved
        if (!$.approvedGrantRecipients[recipient]) {
            revert NotApprovedRecipient(recipient);
        }
        // Check if within maxGrant
        if (amount > $.maxGrantAmount) {
            revert AmountExceedsMaxGrant(amount, $.maxGrantAmount);
        }

        bool inWETH = $.prefersWETH[recipient];

        // Ensure we have enough ETH; if not, unwrap from WETH
        uint256 ethBal = address(this).balance;
        if (ethBal < amount) {
            uint256 deficit = amount - ethBal;
            uint256 vaultWethBal = _WETH.balanceOf(address(this));
            if (vaultWethBal < deficit) {
                revert NotEnoughWETHToUnwrap(deficit);
            }
            _WETH.withdraw(deficit);
        }

        if (inWETH) {
            // Convert ETH -> WETH
            (bool ok, ) = address(_WETH).call{value: amount}(
                abi.encodeWithSignature("deposit()")
            );
            if (!ok) {
                revert WETHDepositFailed();
            }
            // Transfer WETH
            bool success = _WETH.transfer(recipient, amount);
            if (!success) {
                revert WETHTransferFailed();
            }
        } else {
            // Pay in ETH
            (bool sent, ) = payable(recipient).call{value: amount}("");
            if (!sent) {
                revert ETHTransferFailed();
            }
        }

        emit GrantPaid(recipient, amount, inWETH);
    }
}
