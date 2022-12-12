// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BUSDToken is ERC20("Binance Coin", "BUSD") {
  uint constant _initial_supply = 100 * (10**18);
  constructor() public {
     _mint(msg.sender, _initial_supply);
  }

  function mint(address _account, uint256 _amount) external {
    _mint(_account, _amount);
  }

  function burn(address _account, uint256 _amount) external {
    _burn(_account, _amount);
  }
}
