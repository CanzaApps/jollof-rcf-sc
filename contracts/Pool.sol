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
            block.timestamp
        );
        poolConfigs[address(_token)] = poolConfig;
        tokenList.push(_token);
        emit PoolInitialized(address(_token), address(_poolConfig));
    }
    
    /**
     * @dev set the  pool. only owner can initialize the pool.
     * @param _token the token address of the stable coin to be used
     * @param _poolConfig the configuration contract of the pool
     */
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
     * @param _token the ERC20 token of the pool
     */
    function deposit(ERC20 _token, uint256 _amount) external nonReentrant {
        PoolConfig memory pool = poolConfigs[address(_token)];
        require(pool.status == PoolStatus.ACTIVE, "This pool is inactive");
        require(_amount > 0, "deposit amount should more than 0");
        Investment storage investment = stakes[msg.sender][address(_token)];
        investment.amount += _amount;
        investment.lastUpdateTimestamp = block.timestamp;
        _token.transferFrom(msg.sender, address(this), _amount);
    }
    
     /**
     * @dev borrow stable coin.
     * @param _token the ERC20 token of the pool
     * @param _amount the amount of the token to deposit
     */
    function borrow(ERC20 _token, uint256 _amount) external nonReentrant {
        PoolConfig storage pool = poolConfigs[address(_token)];
        require(
            pool.status == PoolStatus.ACTIVE,
            "This pool is not active, Can't borrow this pool"
        );
        require(_amount > 0, "borrow amount should be more than 0");
        require(
            _amount <= getTotalAvailableLiquidity(_token),
            "amount is more than available liquidity on pool"
        );
        uint256 upFrontFee = calculateUpfrontFee(_token, _amount);
        Debt storage debt = debts[msg.sender][address(_token)];
        debt.amountBorrowed += _amount;
        debt.debtAccrued += _amount + upFrontFee;
        debt.lastUpdateTimestamp = block.timestamp;
        //if a user has repaid his position to 0, starts a new borrow
        if (debt.debtAccrued <= 0) {
            debt.borrowedTimestamp = block.timestamp;
        }
        pool.totalBorrows += _amount;
        _token.transfer(msg.sender, _amount);
        emit Borrow(address(_token), msg.sender, _amount);
    }

    /**
     * @dev calculate up front fee.
     * @param _token the ERC20 token of the pool
     * @param drawdownAmount the amount drawn
     */
    function calculateUpfrontFee(ERC20 _token, uint256 drawdownAmount)
        internal
        view
        returns (uint256)
    {
        PoolConfig storage pool = poolConfigs[address(_token)];
        return pool.poolConfig.getUpfrontFee() * drawdownAmount;
    }


    function getTotalAvailableLiquidity(ERC20 _token)
        public
        view
        returns (uint256)
    {
        return _token.balanceOf(address(this));
    }

    function calculateUserInterest(
        ERC20 _token,
        uint256 debt,
        uint256 period
    ) internal view returns (uint256) {
        PoolConfig memory pool = poolConfigs[address(_token)];
        return (pool.poolConfig.getInterestRate() * debt * period) / 1e18;
    }

    function calculateUserPenaltyInterestRate(
        ERC20 _token,
        uint256 debt,
        uint256 period
    ) internal view returns (uint256) {
        PoolConfig memory pool = poolConfigs[address(_token)];
        return
            ((pool.poolConfig.getInterestRate() *
                (1 + pool.poolConfig.getPenaltyRate())) *
                debt *
                period) / 1e18;
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
        return
            min(undawnBalance, commitmentAmount) *
            commitmentFee *
            interestRate *
            period;
    }

    function getUndrawnBalance(ERC20 _token) internal view returns (uint256) {
        PoolConfig memory pool = poolConfigs[address(_token)];
        return
            pool.poolConfig.getCommitmentAmountUsdValue() - pool.totalBorrows;
    }

    function repay(ERC20 _token, uint256 _amount) external nonReentrant {
        Debt storage debt = debts[msg.sender][address(_token)];
        PoolConfig memory pool = poolConfigs[address(_token)];
        uint256 period = block.timestamp - debt.borrowedTimestamp;
        bool isPenalty;
        if (debt.borrowedTimestamp + 14 days > block.timestamp) {
            isPenalty = true;
        } else {
            isPenalty = false;
        }
        uint256 commitmentFee = calculateCommitmentFee(
            getUndrawnBalance(_token),
            pool.poolConfig.getCommitmentAmountUsdValue(),
            pool.poolConfig.getCommitmentFee(),
            pool.poolConfig.getInterestRate(),
            period
        );
        uint256 interestAccrued = calculateInterestAccrued(
            _token,
            debt.debtAccrued,
            period,
            isPenalty
        );
        uint256 payback = debt.debtAccrued + interestAccrued + commitmentFee;
        debt.debtAccrued = payback - _amount;
        debt.lastUpdateTimestamp = block.timestamp;
        _token.transferFrom(msg.sender, address(this), _amount);
    }

    function calculateInterestAccrued(
        ERC20 _token,
        uint256 _debt,
        uint256 period,
        bool isPenalty
    ) internal view returns (uint256) {
        uint256 interestAccrued;
        if (isPenalty) {
            interestAccrued = calculateUserPenaltyInterestRate(
                _token,
                _debt,
                period
            );
        } else {
            interestAccrued = calculateUserInterest(_token, _debt, period);
        }
        return interestAccrued;
    }

    //Things to do
    //create a modifier that updates the undrawn balance in a state which is called on borrow
    //modify the commitment fee calculation to read from it
}
