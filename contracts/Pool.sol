// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

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

    //events
    event PoolInitialized(address tokenAddress, address configAddress);

    event UpdateConfig(address configAddress, uint256 updatedTime);

    event Borrow(address token, address borrower, uint256 amount, uint256 totalBorrow);

    event Deposit(address token, address depositor, uint256 amount, uint256 totalDeposit);

    event Repay(address token, address repayer, uint256 interestPaid, uint256 commitmentFeePaid, uint256 timestamp, uint256 amount);


    struct PoolConfig {
        ERC20 tokenAddress;
        IPoolConfiguration poolConfig;
        uint256 totalBorrows;
        PoolStatus status;
        uint256 lastUpdateTimestamp;
        uint256 totalDeposit;
        uint256 totalInterestPaid;
        uint256 totalCommitmentFeePaid;
        uint256 totalWithdraw;
    }

    // Whitelist mapping
    mapping(address => bool) public whitelistedAddresses;

    // Modifier to restrict function calls to whitelisted addresses
    modifier onlyWhitelisted() {
        require(whitelistedAddresses[msg.sender], "Caller is not whitelisted");
        _;
    }

    
    mapping(address => PoolConfig) public poolConfigs;


    bool private reentrancyLock = false;
    uint256 timeDivisor;  // 31,536,000


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

    struct Withdraw {
        uint256 amount;
        uint256 lastUpdateTimestamp;
        address poolToken;
        address userAddress;
    }

    struct RepayDebt {
        uint256 amount;
        address poolToken;
        uint256 repayTimestamp;
    }

    struct InterestPaid {
        uint256 amount;
        address userAddress;
        uint256 timestamp;
    }

    mapping(address => mapping(address => Investment)) public stakes;
    //maps user's address => token's address => debt
    mapping(address => mapping(address => Debt)) public debts;
    mapping(address =>  Withdraw[]) public withdraws;
    mapping(address => RepayDebt[]) public repayDebt;

    //map interest paid to ERC20 token
    mapping(address => InterestPaid[]) public interestPaid;

    mapping(address => address[]) public borrowersForToken;

    // Mapping to efficiently check if an address is an active borrower for a token
    // Maps token address => (borrower address => index in borrowersForToken array + 1)
    // Using index + 1 allows us to differentiate between not present (0) and index 0.
    mapping(address => mapping(address => uint256)) private borrowerIndex;


    // modifier updatePoolWithInterestSAndTimestamp(ERC20 _token) {
    //     PoolConfig storage poolConfig = poolConfigs[address(_token)];
    // }

 constructor(
        // uint256 _timeDivisor
    ) Ownable() {
        timeDivisor = 365;
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
        PoolConfig memory poolConfig = PoolConfig(
            _token,
            _poolConfig,
            0,
            PoolStatus.ACTIVE,
            block.timestamp,
            0,
            0,
            0,
            0
        );
        poolConfigs[address(_token)] = poolConfig;
        tokenList.push(_token);
        emit PoolInitialized(address(_token), address(_poolConfig));
    }

        // Function to add an address to the whitelist
    function addToWhitelist(address _address) external onlyOwner {
        console.log("added");
        whitelistedAddresses[_address] = true;
    }

    // Function to remove an address from the whitelist
    function removeFromWhitelist(address _address) external onlyOwner {
        whitelistedAddresses[_address] = false;
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
     * @dev Adds a borrower to the list for a token if not already present.
     * @param token The token for which the borrower is to be added.
     * @param borrower The borrower to add.
     */
    function _addBorrowerForToken(address token, address borrower) internal {
        if (borrowerIndex[token][borrower] == 0) { // Not already a borrower
            borrowersForToken[token].push(borrower);
            // Set the borrower's index in the array, adding 1 to differentiate from default value
            borrowerIndex[token][borrower] = borrowersForToken[token].length;
        }
    }

     /**
     * @dev Removes a borrower from the list for a token.
     * @param token The token for which the borrower is to be removed.
     * @param borrower The borrower to remove.
     */
    function _removeBorrowerForToken(address token, address borrower) internal {
        uint256 index = borrowerIndex[token][borrower];
        if (index > 0) { // Borrower is present
            uint256 lastIndex = borrowersForToken[token].length - 1;
            address lastBorrower = borrowersForToken[token][lastIndex];

            // Move the last borrower to the position of the one to remove
            borrowersForToken[token][index - 1] = lastBorrower;
            borrowerIndex[token][lastBorrower] = index; // Update the moved borrower's index

            // Remove the last element
            borrowersForToken[token].pop();
            borrowerIndex[token][borrower] = 0; // Reset the removed borrower's index
        }
    }

     /**
     * @dev Get a list of borrowers for a given token.
     * @param token The token to get borrowers for.
     * @return An array of addresses who are borrowers for the given token.
     */
    function getBorrowersForToken(address token) public view returns (address[] memory) {
        return borrowersForToken[token];
    }

    /**
     * @dev Calculates and applies interest for all active loans across all tokens.
     */
    function calculateInterestForAllLoans() external {
        for (uint256 i = 0; i < tokenList.length; i++) {
            ERC20 token = tokenList[i];
            // Assuming you have a way to get a list of borrowers for each token
            address[] memory borrowers = getBorrowersForToken(address(token));
            for (uint256 j = 0; j < borrowers.length; j++) {
                address borrower = borrowers[j];
                _calculateAndApplyInterest(token, borrower);
            }
        }
    }

    /**
     * @dev Private helper function to calculate and apply interest for a given loan.
     * @param token The ERC20 token of the loan.
     * @param borrower The address of the borrower.
     */
    function _calculateAndApplyInterest(ERC20 token, address borrower) private {
        Debt storage debt = debts[borrower][address(token)];
        if (debt.amountBorrowed == 0) {
            // No active loan for this borrower and token
            return;
        }

        uint256 period = block.timestamp - debt.lastUpdateTimestamp;
        bool isPenalty = checkIsPenalty(debt.borrowedTimestamp);
        uint256 interestAccrued = calculateInterestAccrued(token, debt.debtAccrued, period, isPenalty);

        // Apply the interest to the debt
        debt.debtAccrued += interestAccrued;
        debt.lastUpdateTimestamp = block.timestamp;
    }


    /**
     * @dev deposit stable coin.
     * @param _amount the amount of the token to deposit
     */
     //TODO: LIMIT deposit to whitelisted users
    function deposit(ERC20 _token, uint256 _amount) external nonReentrant onlyWhitelisted {
        console.log("_amount", _amount);
        PoolConfig storage pool = poolConfigs[address(_token)];
        require(
            pool.status == PoolStatus.ACTIVE,
            "This pool is inactive"
        );
        require(_amount > 0, "deposit amount should more than 0");
        Investment storage investment = stakes[msg.sender][address(_token)];
         investment.amount += _amount;
         investment.lastUpdateTimestamp = block.timestamp;
         uint256 totalDeposit = pool.totalDeposit + _amount;
         pool.totalDeposit = totalDeposit;
        _token.transferFrom(msg.sender, address(this), _amount);
        emit Deposit(address(_token), msg.sender, _amount, totalDeposit);
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
        // if(debt.debtAccrued <= 0){
        //     debt.borrowedTimestamp = block.timestamp;
        // }
         pool.totalBorrows += _amount;
         uint256 totalBorrow =  pool.totalBorrows;
         _addBorrowerForToken(address(_token), msg.sender);
         _token.transfer(msg.sender, _amount);
         emit Borrow(address(_token), msg.sender, _amount, totalBorrow);
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
      return (pool.poolConfig.getInterestRate() * debt * period) / (timeDivisor * 1e18); 
  }

  function calculateUserPenaltyInterestRate(ERC20 _token, uint256 debt, uint256 period) internal view returns (uint256) {
      PoolConfig memory pool = poolConfigs[address(_token)];
      return ((pool.poolConfig.getInterestRate() * ((1 * 1e18) + pool.poolConfig.getPenaltyRate())) * debt * period) / (timeDivisor * 1e18 * 1e18); 
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a <= b ? a : b;
}

  function getUserDebtAccrued(ERC20 _token, address userAddress) external view returns(uint256) {
     return _getUserDebtAccrued(_token, userAddress);
  }

  function _getUserDebtAccrued(ERC20 _token, address userAddress) internal view returns(uint256) {
    console.log("time", block.timestamp);
     Debt storage debt  = debts[userAddress][address(_token)];
     if(debt.debtAccrued == 0){
         return 0;
     }
    PoolConfig memory pool = poolConfigs[address(_token)];
    bool isPenalty = checkIsPenalty(debt.borrowedTimestamp);
    uint256 period = block.timestamp - debt.lastUpdateTimestamp;
    uint256 dayCount = period / 86400;
     console.log("period", period);
    console.log("dayCount", dayCount);
    console.log("undrawn", getUndrawnBalance(_token));
    uint256 commitmentFee = calculateCommitmentFee(getUndrawnBalance(_token), pool.poolConfig.getCommitmentAmountUsdValue(), pool.poolConfig.getCommitmentFee(), pool.poolConfig.getInterestRate(), dayCount, timeDivisor);
    console.log("commitmentFee", commitmentFee);
    uint256 interestAccrued = calculateInterestAccrued(_token, debt.debtAccrued, dayCount, isPenalty);
    console.log("debt", debt.debtAccrued);
    console.log("interest", interestAccrued);
    console.log("commitment", commitmentFee);
    return debt.debtAccrued + interestAccrued + commitmentFee;

  }



  function calculateCommitmentFee(
        uint256 undawnBalance,
        uint256 commitmentAmount,
        uint256 commitmentFee,
        uint256 interestRate,
        uint256 period,
        uint256 _timeDivisor
    ) internal pure returns (uint256) {
        return (min(undawnBalance, commitmentAmount) * commitmentFee * interestRate * period) / (_timeDivisor * 1e18 * 1e18);
    }

    function getUndrawnBalance(ERC20 _token) internal view returns (uint256){
        PoolConfig memory pool = poolConfigs[address(_token)];
        return pool.poolConfig.getCommitmentAmountUsdValue() -  pool.totalBorrows;
    }

    function checkIsPenalty(uint256 borrowedTimestamp) internal view returns (bool) {
        return block.timestamp > borrowedTimestamp + 14 days;
    }

  function repay(ERC20 _token, uint256 _amount) external nonReentrant {
      Debt storage debt  = debts[msg.sender][address(_token)];
      PoolConfig storage pool = poolConfigs[address(_token)];
      uint256 period = block.timestamp - debt.lastUpdateTimestamp;
      uint256 dayCount = period / 86400;
      bool isPenalty = checkIsPenalty(debt.borrowedTimestamp);
      uint256 commitmentFee = calculateCommitmentFee(getUndrawnBalance(_token), pool.poolConfig.getCommitmentAmountUsdValue(), pool.poolConfig.getCommitmentFee(), pool.poolConfig.getInterestRate(), dayCount, timeDivisor);
      uint256 interestAccrued = calculateInterestAccrued(_token, debt.debtAccrued, dayCount, isPenalty);
      uint256 payback = debt.debtAccrued + interestAccrued + commitmentFee;
      //if a user pays more than the debt, set debt to zero
      if((payback - _amount) <= 0){
        _removeBorrowerForToken(address(_token), msg.sender);
          debt.debtAccrued  = 0;
      }else{
          debt.debtAccrued = payback - _amount;
      }
      debt.amountBorrowed -= _amount;
      debt.lastUpdateTimestamp = block.timestamp;
      pool.totalInterestPaid += interestAccrued;
      pool.totalCommitmentFeePaid += commitmentFee;
      //pool.totalBorrows -= _amount;
      RepayDebt memory repay_ = RepayDebt(_amount, address(_token), block.timestamp);
      repayDebt[msg.sender].push(repay_);
       _token.transferFrom(msg.sender, address(this), _amount);
      emit Repay(address(_token), msg.sender, interestAccrued,  commitmentFee,  block.timestamp, _amount);
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



  function withdraw(ERC20 _token, uint256 _amount) external nonReentrant {
      PoolConfig storage pool = poolConfigs[address(_token)];
      Investment storage investment = stakes[msg.sender][address(_token)];
     require(_amount <= calculateUserAvailableAmountForWithdrawal_(_token, msg.sender), "You have exceeded the amount you can withdraw");
     Withdraw memory withdraw_ = Withdraw(_amount, block.timestamp, address(_token), msg.sender);
     withdraws[msg.sender].push(withdraw_);
     pool.totalWithdraw +=  _amount;
     pool.totalDeposit -= _amount;
     investment.amount -= _amount;
     _token.transfer(msg.sender, _amount);

  }

  function getUserTotalDeposit(ERC20 _token, address userAddress) external view returns(uint256) {
    return getUserTotalDeposit_(_token, userAddress);
  }

  function getUserTotalDeposit_(ERC20 _token, address userAddress) internal view returns(uint256) {
    Investment memory investment = stakes[userAddress][address(_token)];
    return investment.amount;
  }

  function calculateUserAvailableAmountForWithdrawal(ERC20 _token, address userAddress) external view returns(uint256) {
      return calculateUserAvailableAmountForWithdrawal_(_token, userAddress);
  }

  function calculateUserAvailableAmountForWithdrawal_(ERC20 _token, address userAddress) internal view returns(uint256) {
      PoolConfig memory pool = poolConfigs[address(_token)];
       uint userDeposit = getUserTotalDeposit_(_token, userAddress);
     uint256 locked =  (userDeposit * 1e18) / getTotalDeposit(_token);
     console.log("userDeposit", userDeposit);
     console.log("getTotalDeposit", getTotalDeposit(_token));
     console.log("locked", locked);
     uint256 lockedAmount = (locked * pool.poolConfig.getCommitmentAmountUsdValue())/1e18;
     console.log("lockedAmount", lockedAmount);
     if(userDeposit <= lockedAmount){
         return 0;
     }
     return userDeposit - lockedAmount;
  }

  function getTotalDeposit(ERC20 _token) internal view returns (uint256) {
      PoolConfig memory pool = poolConfigs[address(_token)];
      return pool.totalDeposit;
  }

  function updateTimeDivisor(uint256 value) external {
      timeDivisor = value;
  }


}
