// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IPoolConfiguration.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

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

    event Deposit(address token, address depositor, uint256 amount);

    event Repay(address token, address repayer, uint256 amount);

    struct PoolConfig {
        ERC20 tokenAddress;
        IPoolConfiguration poolConfig;
        uint256 totalBorrows;
        PoolStatus status;
        uint256 lastUpdateTimestamp;
        uint256 totalDeposit;
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
        uint256 borrowedTimestamp;
    }

    mapping(address => mapping(address => Investment)) public stakes;
    mapping(address => mapping(address => Debt)) public debts;

    // modifier updatePoolWithInterestSAndTimestamp(ERC20 _token) {
    //     PoolConfig storage poolConfig = poolConfigs[address(_token)];
    // }


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
            block.timestamp,
            0
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
     * @param _amount the amount of the token to deposit
     */
    function deposit(ERC20 _token, uint256 _amount) external nonReentrant {
        PoolConfig storage pool = poolConfigs[address(_token)];
        require(
            pool.status == PoolStatus.ACTIVE,
            "This pool is inactive"
        );
        require(_amount > 0, "deposit amount should more than 0");
        Investment storage investment = stakes[msg.sender][address(_token)];
         investment.amount += _amount;
         investment.lastUpdateTimestamp = block.timestamp;
         pool.totalDeposit += _amount;
        _token.transferFrom(msg.sender, address(this), _amount);
        emit Deposit(address(_token), msg.sender, _amount);
    }


    function borrow(ERC20 _token, uint256 _amount) external nonReentrant {
        PoolConfig storage pool = poolConfigs[address(_token)];
        require(pool.status == PoolStatus.ACTIVE, "This pool is not active, Can't borrow this pool");
        require(_amount > 0, "borrow amount should be more than 0");
        require(_amount <= getTotalAvailableLiquidity(_token), "amount is more than available liquidity on pool");
        uint256 upFrontFee = calculateUpfrontFee(_token, _amount);
        Debt storage debt = debts[msg.sender][address(_token)];
        debt.amountBorrowed += _amount;
        uint256 totalDebt = _amount +  upFrontFee;
        debt.debtAccrued += totalDebt;
        debt.lastUpdateTimestamp = block.timestamp;
        debt.borrowedTimestamp = block.timestamp;
        //if a user has repaid his position to 0, starts a new borrow
        if(debt.debtAccrued <= 0){
            debt.borrowedTimestamp = block.timestamp;
        }
         pool.totalBorrows += _amount;
         _token.transfer(msg.sender, _amount);
         emit Borrow(address(_token), msg.sender, _amount);
    }

    function calculateUpfrontFee(ERC20 _token, uint256 drawdownAmount) internal view returns (uint256) {
      PoolConfig storage pool = poolConfigs[address(_token)];
       return (pool.poolConfig.getUpfrontFee() * drawdownAmount) / 1e18;
    }

      function getTotalAvailableLiquidity(ERC20 _token) public view returns (uint256) {
    return _token.balanceOf(address(this));
  }


  function calculateUserInterest(ERC20 _token, uint256 debt, uint256 period) internal view returns (uint256) {
      PoolConfig memory pool = poolConfigs[address(_token)];
      return (pool.poolConfig.getInterestRate() * debt * period) / (15 * 1e18); 
  }

  function calculateUserPenaltyInterestRate(ERC20 _token, uint256 debt, uint256 period) internal view returns (uint256) {
      PoolConfig memory pool = poolConfigs[address(_token)];
      return ((pool.poolConfig.getInterestRate() * (1 + pool.poolConfig.getPenaltyRate())) * debt * period) / (15 * 1e18 * 1e18); 
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a <= b ? a : b;
}

  function calculateCommitmentFee(
        uint256 undawnBalance,
        uint256 commitmentAmount,
        uint256 commitmentFee,
        uint256 interestRate,
        uint256 period
    ) internal pure returns (uint256) {
        return (min(undawnBalance, commitmentAmount) * commitmentFee * interestRate * period) / (15 * 1e18 * 1e18);
    }

    function getUndrawnBalance(ERC20 _token) internal view returns (uint256){
        PoolConfig memory pool = poolConfigs[address(_token)];
        return pool.poolConfig.getCommitmentAmountUsdValue() -  pool.totalBorrows;
    }

    function checkIsPenalty(uint256 borrowedTimestamp) internal view returns (bool) {
         if(borrowedTimestamp + 14 days > block.timestamp){
           return true;
      }else{
          return false;
      }
    }

  function repay(ERC20 _token, uint256 _amount) external nonReentrant {
      Debt storage debt  = debts[msg.sender][address(_token)];
      PoolConfig memory pool = poolConfigs[address(_token)];
      uint256 period = block.timestamp - debt.borrowedTimestamp;
      bool isPenalty;
      if(debt.borrowedTimestamp + 14 days > block.timestamp){
         isPenalty = true;
      }else{
         isPenalty = false;
      }
      uint256 commitmentFee = calculateCommitmentFee(getUndrawnBalance(_token), pool.poolConfig.getCommitmentAmountUsdValue(), pool.poolConfig.getCommitmentFee(), pool.poolConfig.getInterestRate(), period);
      console.log("period", period);
      uint256 interestAccrued = calculateInterestAccrued(_token, debt.debtAccrued, period, isPenalty);
      console.log(interestAccrued);
          console.log(commitmentFee);
      uint256 payback = debt.debtAccrued + interestAccrued + commitmentFee;
      console.log("debt", debt.debtAccrued);
      debt.debtAccrued = payback - _amount;
      debt.lastUpdateTimestamp = block.timestamp;
       _token.transferFrom(msg.sender, address(this), _amount);
       emit Repay(address(_token), msg.sender, _amount);
  }

  function calculateInterestAccrued(ERC20 _token, uint256 _debt, uint256 period, bool isPenalty) internal view returns(uint256) {
      uint256 interestAccrued;
      if(isPenalty){
         interestAccrued = calculateUserPenaltyInterestRate(_token, _debt, period);
      }else{
         interestAccrued = calculateUserInterest(_token, _debt, period);
      }
      return interestAccrued;
  }

  function getUserDebtAccrued(ERC20 _token) external view returns(uint256) {
     Debt storage debt  = debts[msg.sender][address(_token)];
    PoolConfig memory pool = poolConfigs[address(_token)];
    bool isPenalty = checkIsPenalty(debt.borrowedTimestamp);
    uint256 period = block.timestamp - debt.borrowedTimestamp;
    uint256 commitmentFee = calculateCommitmentFee(getUndrawnBalance(_token), pool.poolConfig.getCommitmentAmountUsdValue(), pool.poolConfig.getCommitmentFee(), pool.poolConfig.getInterestRate(), period);
    uint256 interestAccrued = calculateInterestAccrued(_token, debt.debtAccrued, period, isPenalty);
    return debt.debtAccrued + interestAccrued + commitmentFee;
  }

}
