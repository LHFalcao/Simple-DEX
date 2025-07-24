// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title TokenA — ERC20 fungible to the SimpleDEX
/// @notice Emits initial supply and allows mint/burn by the deployer
contract TokenA is ERC20 {
    constructor(uint256 initialSupply) ERC20("Token A", "TKA") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}