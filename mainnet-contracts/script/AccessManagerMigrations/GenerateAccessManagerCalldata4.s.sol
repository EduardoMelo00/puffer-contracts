// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import {PufferVaultV3_Grant} from "../../src/PufferVaultV3_Grant.sol";
import {console} from "forge-std/console.sol";
import {ROLE_ID_GRANT_MANAGER} from "../../script/Roles.sol"; // se criou

contract GenerateAccessManagerCalldata4 is Script {
    function run(
        address pufferVaultProxy,
        address newGrantManagerAccount
    ) public pure returns (bytes memory) {
        bytes[] memory calldatas = new bytes[](2);

        bytes4[] memory grantSelectors = new bytes4[](3);

        grantSelectors[0] = PufferVaultV3_Grant.setMaxGrantAmount.selector;
        grantSelectors[1] = PufferVaultV3_Grant.approveGrantRecipient.selector;
        grantSelectors[2] = PufferVaultV3_Grant.payGrant.selector;

        calldatas[0] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            pufferVaultProxy,
            grantSelectors,
            ROLE_ID_GRANT_MANAGER
        );

        calldatas[1] = abi.encodeWithSelector(
            AccessManager.grantRole.selector,
            ROLE_ID_GRANT_MANAGER,
            newGrantManagerAccount,
            0
        );

        return abi.encodeCall(Multicall.multicall, (calldatas));
    }
}
