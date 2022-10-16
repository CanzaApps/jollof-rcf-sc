// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IPoolConfiguration.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract JToken is ERC20, ERC20Burnable, Ownable, Pausable {
    constructor(string memory _name, string memory _symbol,  uint _totalSupply) ERC20(_name, _symbol){

    }

    function mint(address _account, uint256 _amount) external onlyOwner {

    }

    function burn(address _account, uint256 _amount) external onlyOwner {
       
    }

}