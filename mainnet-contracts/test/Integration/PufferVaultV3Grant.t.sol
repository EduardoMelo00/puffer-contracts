// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {MainnetForkTestHelper} from "../MainnetForkTestHelper.sol";
import {PufferVaultV3_Grant} from "../../src/PufferVaultV3_Grant.sol";
import {IPufferOracle} from "../../src/interface/IPufferOracle.sol";
import {MockPufferOracle} from "../mocks/MockPufferOracle.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ILidoWithdrawalQueue} from "../../src/interface/Lido/ILidoWithdrawalQueue.sol";
import {IEigenLayer} from "../../src/interface/EigenLayer/IEigenLayer.sol";
import {IStrategy} from "../../src/interface/EigenLayer/IStrategy.sol";
import {IDelegationManager} from "../../src/interface/EigenLayer/IDelegationManager.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ROLE_ID_GRANT_MANAGER} from "../../script/Roles.sol";

/**
 * @title PufferVaultV3Grant
 * @notice Example test that upgrades the existing PufferVault (on mainnet fork) to a new "GrantVaultV3" contract,
 *         then runs checks including payGrant tests.
 */
contract PufferVaultV3Grant is MainnetForkTestHelper {
    PufferVaultV3_Grant public PufferVaultV3_GrantImplementation;

    // Community multisig addresses
    address constant EIGENLAYER_MULTISIG =
        0xFEA47018D632A77bA579846c840d5706705Dc598;
    address constant PUFFER_COMMUNITY_MULTISIG =
        0x446d4d6b26815f9bA78B5D454E303315D586Cb2a;

    address GRANT_MANAGER_ADDR;

    function setUp() public override {
        super.setUp();

        vm.startPrank(address(timelock));

        bytes4[] memory grantSelectors = new bytes4[](3);
        grantSelectors[0] = PufferVaultV3_Grant.setMaxGrantAmount.selector;
        grantSelectors[1] = PufferVaultV3_Grant.approveGrantRecipient.selector;
        grantSelectors[2] = PufferVaultV3_Grant.payGrant.selector;

        accessManager.setTargetFunctionRole(
            address(pufferVault),
            grantSelectors,
            ROLE_ID_GRANT_MANAGER
        );

        GRANT_MANAGER_ADDR = makeAddr("grantMgr");
        accessManager.grantRole(ROLE_ID_GRANT_MANAGER, GRANT_MANAGER_ADDR, 0);

        vm.stopPrank();

        address managerAddr = _myGetEigenDelegationManager();
        PufferVaultV3_GrantImplementation = new PufferVaultV3_Grant(
            _ST_ETH,
            _WETH,
            ILidoWithdrawalQueue(_getLidoWithdrawalQueue()),
            IStrategy(_getStETHStrategy()),
            IEigenLayer(_getEigenLayerStrategyManager()),
            IPufferOracle(_getPufferOracle()),
            IDelegationManager(managerAddr)
        );
        console.log(
            "New V4 Implementation deployed at:",
            address(PufferVaultV3_GrantImplementation)
        );

        _upgradeToMainnetV4Puffer(address(PufferVaultV3_GrantImplementation));
    }

    function _upgradeToMainnetV4Puffer(address newImplementation) internal {
        vm.startPrank(address(timelock));
        vm.expectEmit(true, true, true, true);
        emit ERC1967Utils.Upgraded(newImplementation);

        UUPSUpgradeable(pufferVault).upgradeToAndCall(newImplementation, "");
        vm.stopPrank();
    }

    function testAfterUpgrade_CanReadTotalAssets_Grant() public view {
        uint256 assets = PufferVaultV3_GrantImplementation.totalAssets();
        console.log("After upgrade, totalAssets =>", assets);
    }

    function testGrantManagerFlow() public {
        // restricted
        vm.startPrank(COMMUNITY_MULTISIG);
        PufferVaultV3_GrantImplementation.setGrantManager(address(0x1234));
        vm.stopPrank();
    }

    /**
     * @notice Approve the known addresses for grants, check isApprovedGrantRecipient
     */
    function testApproveGrantRecipients() public {
        vm.startPrank(GRANT_MANAGER_ADDR);

        // set the maxGrant
        PufferVaultV3_GrantImplementation.setMaxGrantAmount(500 ether);

        PufferVaultV3_GrantImplementation.approveGrantRecipient(
            EIGENLAYER_MULTISIG,
            true
        );
        PufferVaultV3_GrantImplementation.approveGrantRecipient(
            PUFFER_COMMUNITY_MULTISIG,
            true
        );

        require(
            PufferVaultV3_GrantImplementation.isApprovedGrantRecipient(
                EIGENLAYER_MULTISIG
            ),
            "EIGENLAYER_MULTISIG not approved"
        );
        require(
            PufferVaultV3_GrantImplementation.isApprovedGrantRecipient(
                PUFFER_COMMUNITY_MULTISIG
            ),
            "PUFFER_COMMUNITY_MULTISIG not approved"
        );

        vm.stopPrank();
    }

    /**
     * @notice Basic test: manager pays a grant to EIGENLAYER_MULTISIG.
     *         We fund the contract with some ETH.
     */
    function testPayGrant() public {
        vm.startPrank(GRANT_MANAGER_ADDR);
        PufferVaultV3_GrantImplementation.approveGrantRecipient(
            EIGENLAYER_MULTISIG,
            true
        );
        PufferVaultV3_GrantImplementation.setMaxGrantAmount(100 ether);
        vm.stopPrank();

        vm.startPrank(EIGENLAYER_MULTISIG);
        PufferVaultV3_GrantImplementation.setGrantPaymentPreference(true);
        vm.stopPrank();

        vm.deal(address(PufferVaultV3_GrantImplementation), 10 ether);

        vm.startPrank(GRANT_MANAGER_ADDR);
        PufferVaultV3_GrantImplementation.payGrant(
            EIGENLAYER_MULTISIG,
            5 ether
        );
        vm.stopPrank();
    }

    //Fuzz
    function testFuzzPayGrant(uint96 fuzzAmount) public {
        uint256 amount = uint256(fuzzAmount) % (200 ether);

        vm.startPrank(GRANT_MANAGER_ADDR);

        PufferVaultV3_GrantImplementation.approveGrantRecipient(
            EIGENLAYER_MULTISIG,
            true
        );

        PufferVaultV3_GrantImplementation.setMaxGrantAmount(100 ether);

        vm.deal(address(PufferVaultV3_GrantImplementation), 200 ether);

        if (amount > 100 ether) {
            vm.expectRevert(
                bytes("PufferVaultV4: Amount exceeds maxGrantAmount")
            );
        }

        PufferVaultV3_GrantImplementation.payGrant(EIGENLAYER_MULTISIG, amount);

        vm.stopPrank();
    }

    function testFuzzPayGrantAmounts(uint96 fuzzAmount) public {
        uint256 amount = uint256(fuzzAmount);

        vm.startPrank(EIGENLAYER_MULTISIG);
        PufferVaultV3_GrantImplementation.setGrantPaymentPreference(true);
        vm.stopPrank();

        vm.deal(address(PufferVaultV3_GrantImplementation), 100 ether);

        vm.startPrank(GRANT_MANAGER_ADDR);

        if (amount > 100 ether) {
            vm.expectRevert("PufferVaultV4: Amount exceeds maxGrantAmount");
        }
        PufferVaultV3_GrantImplementation.payGrant(EIGENLAYER_MULTISIG, amount);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to pick the correct Eigen DelegationManager address for mainnet or Holesky
     */
    function _myGetEigenDelegationManager() internal view returns (address) {
        if (block.chainid == 1) {
            return 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A;
        } else if (block.chainid == 17000) {
            return 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
        }
        revert("DelegationManager not available for this chain");
    }
}
