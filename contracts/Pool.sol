// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IPoolConfiguration.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is Ownable, Pausable {
    enum PoolStatus {
        INACTIVE,
        ACTIVE,
        CLOSED
    }

      ERC20[] public tokenList;
    event PoolInitialized(address tokenAddress, address configAddress);

    event UpdateConfig(address configAddress, uint256 updatedTime);

    struct PoolConfig {
        ERC20 tokenAddress;
        IPoolConfiguration poolConfig;
        uint256 totalBorrows;
        PoolStatus status;
    }
    mapping(address => PoolConfig) public poolConfigs;
    bool private reentrancyLock = false;
    modifier nonReentrant() {
        require(!reentrancyLock);
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    /**
     * @dev initialize the  pool. only owner can initialize the pool.
     * @param _token the token address of the stable coin to be used
     * @param _poolConfig the configuration contract of the pool
     */
    function initPool(ERC20 _token, IPoolConfiguration _poolConfig)
        external
        onlyOwner
    {
        PoolConfig memory poolConfig = PoolConfig(_token, _poolConfig, 0, PoolStatus.ACTIVE);
        poolConfigs[address(_token)] = poolConfig;
        tokenList.push(_token);
        emit PoolInitialized(address(_token), address(_poolConfig));
    }

    /**
     * @dev update the  config. only owner can initialize the pool.
     * @param _poolConfig the configuration contract of the pool
     */
    function updatePoolConfig(ERC20 _token, IPoolConfiguration _poolConfig)
        external
        onlyOwner
    {
        PoolConfig storage poolConfig = poolConfigs[address(_token)];
        poolConfig.poolConfig = _poolConfig;
        emit UpdateConfig(address(_poolConfig), block.timestamp);
    }

    function updatePool(ERC20 _token, IPoolConfiguration _poolConfig) external onlyOwner{
      
    }

     /**
     * @dev deposit stable coin.
     * @param amount the amount of the token to deposit
     */
    function deposit(ERC20 _token, uint256 amount) external nonReentrant {
        PoolConfig memory poolConfig;
        require(poolConfig.status == PoolStatus.ACTIVE, "This pool is inactive");
        require(amount > 0, "deposit amount should more than 0");
        _token.transferFrom(msg.sender, address(this), amount);
    }
}
