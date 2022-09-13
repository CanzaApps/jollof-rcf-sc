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

    event Borrow(address token, address borrower, uint256 amount);

    struct PoolConfig {
        ERC20 tokenAddress;
        IPoolConfiguration poolConfig;
        uint256 totalBorrows;
        PoolStatus status;
        uint256 lastUpdateTimestamp;
    }
    mapping(address => PoolConfig) public poolConfigs;
    bool private reentrancyLock = false;
    modifier nonReentrant() {
        require(!reentrancyLock);
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    struct Investment {
        uint256 amount;
        uint256 lastUpdateTimestamp;
    }

    struct Debt {
        uint256 amountBorrowed;
        uint256 debtAccrued;
        uint256 lastUpdateTimestamp;
    }

    mapping(address => Investment) public stakes;
    mapping(address => Debt) public debts;

    /**
     * @dev initialize the  pool. only owner can initialize the pool.
     * @param _token the token address of the stable coin to be used
     * @param _poolConfig the configuration contract of the pool
     */
    function initPool(ERC20 _token, IPoolConfiguration _poolConfig)
        external
        onlyOwner
    {
        PoolConfig memory poolConfig = PoolConfig(
            _token,
            _poolConfig,
            0,
            PoolStatus.ACTIVE,
            block.timestamp
        );
        poolConfigs[address(_token)] = poolConfig;
        tokenList.push(_token);
        emit PoolInitialized(address(_token), address(_poolConfig));
    }

    function setPoolConfig(ERC20 _token, IPoolConfiguration _poolConfig)
        external
        onlyOwner
    {
        PoolConfig storage pool = poolConfigs[address(_token)];
        require(
            address(pool.tokenAddress) != address(0),
            "This token hasn't been initialized on the pool, can't set the pool config"
        );
        pool.poolConfig = _poolConfig;
        emit UpdateConfig(address(_token), block.timestamp);
    }

    /**
     * @dev deposit stable coin.
     * @param amount the amount of the token to deposit
     */
    function deposit(ERC20 _token, uint256 amount) external nonReentrant {
        PoolConfig memory poolConfig;
        require(
            poolConfig.status == PoolStatus.ACTIVE,
            "This pool is inactive"
        );
        require(amount > 0, "deposit amount should more than 0");
        Investment memory investment = Investment(amount, block.timestamp);
        stakes[msg.sender] = investment;
        _token.transfer(msg.sender, amount);
    }

    function calculateCommitmentFee(
        uint256 undawnBalance,
        uint256 commitmentAmount
    ) internal pure returns (uint256) {

    }

    function borrow(ERC20 _token, uint256 _amount) external nonReentrant {
        PoolConfig storage pool = poolConfigs[address(_token)];
        require(pool.status == PoolStatus.ACTIVE, "This pool is not active, Can't borrow this pool");
        require(_amount > 0, "borrow amount should be more than 0");
        require(_amount <= getTotalAvailableLiquidity(_token), "amount is more than available liquidity on pool");
        uint256 upFrontFee = calculateUpfrontFee(_token, _amount);
        Debt memory debt = Debt(_amount, _amount + upFrontFee, block.timestamp);
         debts[msg.sender] = debt;
         pool.totalBorrows += _amount;
         _token.transfer(msg.sender, _amount);
         emit Borrow(address(_token), msg.sender, _amount);
    }

    function calculateUpfrontFee(ERC20 _token, uint256 drawdownAmount) public view returns (uint256) {
      PoolConfig storage pool = poolConfigs[address(_token)];
       return pool.poolConfig.getUpfrontFee() * drawdownAmount;
    }

      function getTotalAvailableLiquidity(ERC20 _token) public view returns (uint256) {
    return _token.balanceOf(address(this));
  }
}
