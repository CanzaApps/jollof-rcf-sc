const { expect } = require('chai')
const { ethers } = require('hardhat')
const poolConfigData = require('../config/pool_config_data.json')
const { time } = require('@nomicfoundation/hardhat-network-helpers')

contract('JOLLOF', async () => {
  try {
    let poolConfigFactory
    let poolConfigContract
    let poolConfigContractAddress
    let busdFactory
    let busdContract
    let busdContractAddress
    let poolFactory
    let poolContract
    let poolContractAddress
    let owner, acc1, acc2, acc3, acc4

    before(async () => {
      try {
        [owner, acc1, acc2, acc3, acc4] = await ethers.getSigners()
        poolConfigFactory = await ethers.getContractFactory('PoolConfiguration')
        const config = poolConfigData['USDT']

        poolConfigContract = await poolConfigFactory.deploy(
          config.interestRate,
          config.commitmentFee,
          config.commitmentAmountUsdValue,
          config.durationOfCommitmentAgreementInDays,
          config.upfrontFee,
          config.penaltyRate,
          config.protocolFee,
        )

        poolConfigContractAddress = poolConfigContract.address

        busdFactory = await ethers.getContractFactory('BUSDToken')
        busdContract = await busdFactory.deploy()
        busdContractAddress = busdContract.address

        poolFactory = await ethers.getContractFactory('Pool')
        poolContract = await poolFactory.deploy()
        poolContractAddress = poolContract.address

        await poolContract.initPool(
          busdContract.address,
          poolConfigContract.address,
        )
        await busdContract.mint(owner.address, '1000000000000000000000000000000')

        
        await poolContract.connect(owner).addToWhitelist(acc1.address);


      } catch (err) {
        console.log(err)
      }
    })

    describe('Pool Contarct', function () {

      async function deposit(amount, user) {
        try{
        console.log("here")
        //await poolContract.connect(acc1).addToWhitelist(acc1.address);
        const [owner] = await ethers.getSigners();
        const balance = await busdContract.balanceOf(owner.address)
        console.log("owner balance", balance)
        await busdContract.connect(owner).approve(owner.address, ethers.utils.parseUnits('1000000', 'ether'))
        await busdContract.transferFrom(owner.address, user.address,  ethers.utils.parseUnits('200000', 'ether'));
        const balance2 = await busdContract.balanceOf(user.address)
        //console.log("balance", balance2)
        await busdContract.connect(user).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))
        return await poolContract.connect(user).deposit(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));
        }catch(err) {
          console.log(err)
        }
      }

      context('deposit', async () => {
        it('Should deposit', async () => {
          const depositAmt = "100000"
         const depositTx = await deposit(depositAmt, acc1);
         
         const balance2 = await busdContract.balanceOf(acc1.address)
        
         await expect(depositTx).to.emit(poolContract, "Deposit").withArgs(busdContract.address, acc1.address, ethers.utils.parseUnits(depositAmt, 'ether'), ethers.utils.parseUnits(depositAmt, 'ether'));
  
        })
        
        it('should borrow', async () => {
          // const poolConfig = await poolContract.poolConfigs(busdContract.address)
          const balance = await busdContract.balanceOf(acc2.address)
          //console.log('2 balance', balance)
          // console.log("pool config", await poolConfig)
          const amount = "10000"
          const borrowTxt = await poolContract.connect(acc2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));

          const  acct2Balance = await busdContract.balanceOf(acc2.address)
          expect(acct2Balance).to.equal(ethers.utils.parseUnits(amount, 'ether'))
          await expect(borrowTxt).to.emit(poolContract, "Borrow").withArgs(busdContract.address, acc2.address, ethers.utils.parseUnits(amount, 'ether'), ethers.utils.parseUnits(amount, 'ether'));

           const poolConfig = await poolContract.poolConfigs(busdContract.address)
            //console.log("pool config", poolConfig)


        })

        it("should fetch user debt accrued", async() => {
            
          const userDebtAccrued = await poolContract.getUserDebtAccrued(busdContractAddress, acc2.address);

          console.log("debt accrued", userDebtAccrued)
         

          await time.increase(86400);
         
          const userDebtAccruedDay2 = await poolContract.getUserDebtAccrued(busdContractAddress, acc2.address);

          console.log("debt2 accrued", userDebtAccruedDay2)

          await time.increase(86400);

          const userDebtAccruedDay3 = await poolContract.getUserDebtAccrued(busdContractAddress, acc2.address);

          console.log("debt3 accrued", userDebtAccruedDay3)
    

        })

        it('should repay', async () => {
          // const poolConfig = await poolContract.poolConfigs(busdContract.address)
          const balance = await busdContract.balanceOf(acc2.address)

          const poolConfigBefore = await poolContract.poolConfigs(busdContract.address)

          const DebtBefore = await poolContract.debts(acc2.address, busdContract.address)

          console.log("cobfig before", poolConfigBefore);

          console.log("Debt before", DebtBefore);
          //console.log('2 balance', balance)
          // console.log("pool config", await poolConfig)
          const amount = "10000"
          await busdContract.connect(acc2).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))
          const borrowTxt = await poolContract.connect(acc2).repay(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));


          const poolConfigAfter = await poolContract.poolConfigs(busdContract.address)

          const DebtAfter = await poolContract.debts(acc2.address, busdContract.address)

          console.log("cobfig after", poolConfigAfter);
          console.log("debt after", DebtAfter);

          // const  acct2Balance = await busdContract.balanceOf(acc2.address)
          // expect(acct2Balance).to.equal(ethers.utils.parseUnits(amount, 'ether'))
          // await expect(borrowTxt).to.emit(poolContract, "Borrow").withArgs(busdContract.address, acc2.address, ethers.utils.parseUnits(amount, 'ether'), ethers.utils.parseUnits(amount, 'ether'));

          //  const poolConfig = await poolContract.poolConfigs(busdContract.address)
            //console.log("pool config", poolConfig)


        })




      })
      // beforeEach(async () => {
      //   try{
      //   console.log("here")
      //   const [owner] = await ethers.getSigners()
      //   poolConfigFactory = await ethers.getContractFactory('PoolConfiguration')
      //   const config = poolConfigData['USDT']
      //   console.log("factory", config)
      //   poolConfigContract = await poolConfigFactory.deploy(
      //     config.interestRate,
      //     config.commitmentFee,
      //     config.commitmentAmountUsdValue,
      //     config.durationOfCommitmentAgreementInDays,
      //     config.upfrontFee,
      //     config.penaltyRate,
      //     config.protocolFee,
      //   )

      //   poolConfigContractAddress = poolConfigContract.address

      //   console.log("poolconfigaddress", poolConfigContractAddress)

      //   busdFactory = await ethers.getContractFactory('BUSDToken')
      //   busdContract = await busdFactory.deploy()
      //   busdContractAddress = busdContract.address

      //   poolFactory = await ethers.getContractFactory('Pool')
      //   poolContract = await poolFactory.deploy(15)
      //   poolContractAddress = poolContract.address;

      //   await poolContract.initPool(busdContract.address, poolConfigContract.address);
      //   await busdContract.mint(owner.address, "100000000000000000000000")

      //   }catch(err) {
      //     console.log(err)
      //   }

      // })

      // it('[PASS] It should initialize pool', async ()=> {
      //   const poolConfig = await poolContract.poolConfigs(busdContract.address)
      //    expect(poolConfig._token).to.equal(busdContractAddress.address)
      //    expect(poolConfig.status).to.equal(1)
      // })

      // async function deposit(amount, user) {
      //   const [owner] = await ethers.getSigners();
      //   const balance = await busdContract.balanceOf(owner.address)
      //   console.log("owner balance", balance)
      //   await busdContract.connect(owner).approve(owner.address, ethers.utils.parseUnits('1000000', 'ether'))
      //   await busdContract.transferFrom(owner.address, user.address,  ethers.utils.parseUnits('100', 'ether'));
      //   const balance2 = await busdContract.balanceOf(user.address)
      //   console.log("balance", balance2)
      //   await busdContract.connect(user).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))
      //   await poolContract.connect(user).deposit(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));
      // }

      // it('[PASS] It should deposit', async ()=> {
      //   const [_, user] = await ethers.getSigners();
      //   const amount = "100"
      //   await deposit(amount, user)
      //   //Expects user balance to zero(0) after depositing
      //   const balanceAfter = await busdContract.balanceOf(user.address);
      //   expect(balanceAfter).to.equal(0);
      //   const poolConfig = await poolContract.poolConfigs(busdContract.address)
      //   //Checks totalDeposit in the pool config  equals total amount deposited
      //   expect(poolConfig.totalDeposit).to.equal(ethers.utils.parseUnits(amount, 'ether'))
      //   const contractBalance = await busdContract.balanceOf(poolContract.address);
      //   expect(contractBalance).to.equal(ethers.utils.parseUnits(amount, 'ether'))
      // })

      // it('[PASS] it should borrow', async ()=> {
      //   const [_, user, user2] = await ethers.getSigners();
      //   const amount = "100"
      //   await deposit(amount, user);

      //   const userBalanceBefore = await busdContract.balanceOf(user.address);

      //   await poolContract.connect(user2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));

      //   const user2Balance = await busdContract.balanceOf(user2.address);
      //   //Excepts user2 balance to be 100
      //   expect(user2Balance).to.equal(ethers.utils.parseUnits(amount, 'ether'))

      //   const commitmentFee = await poolConfigContract.getCommitmentFee();
      //   const upFrontFee = ethers.utils.formatEther(commitmentFee) * +amount
      //   const debts = await poolContract.debts(user2.address, busdContractAddress)
      //   const amountBorrowed = debts.amountBorrowed;
      //   const debtAccrued = debts.debtAccrued;
      //   console.log("amount borrowed", amountBorrowed);
      //   console.log("upfront fee", upFrontFee)
      //   console.log("debt accrued", ethers.utils.formatEther(debtAccrued))
      //  // console.log("Poolconfig", debts);
      // })

      // it('[PASS] gets debt accrued', async() => {
      //   const [_, user1, user2] = await ethers.getSigners();
      //   const amount = "100"
      //   await deposit(amount, user1);
      //   await poolContract.connect(user2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));

      //   const userDebtAccrued = await poolContract.getUserDebtAccrued(busdContractAddress, user2.address);
      //   // console.log("user debt", ethers.utils.formatEther(userDebtAccrued));
      //   // await time.increase(3600);
      //   // const userDebtAccrued2 = await poolContract.getUserDebtAccrued(busdContractAddress, user2.address);
      //   // console.log("After 1 day", ethers.utils.formatEther(userDebtAccrued2));
      // })

      // it('[PASS] repay debt', async () => {
      //   const [_, user1, user2] = await ethers.getSigners();
      //   const amount = "100.0"
      //   await deposit(amount, user1);
      //   await poolContract.connect(user2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));

      //   //check balance before repaying debt
      //   const balanceBefore = await busdContract.balanceOf(user2.address);
      //   console.log("balance before,", ethers.utils.formatEther(balanceBefore));

      //   //Approve token
      //   await busdContract.connect(user2).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))

      //   expect(ethers.utils.formatEther(balanceBefore)).to.equal(amount)

      //   //Repy debt
      //   await poolContract.connect(user2).repay(busdContractAddress, ethers.utils.parseUnits(amount, 'ether'));

      //   //Check balance after
      //   const balanceAfter = await busdContract.balanceOf(user2.address);
      //   console.log("balance after", ethers.utils.formatEther(balanceAfter))

      //   const debts = await poolContract.debts(user2.address, busdContractAddress);
      //   const debtAccrued = debts.debtAccrued
      //   console.log("debt accrued", debts.debtAccrued)
      //   console.log("debts", ethers.utils.formatEther(debtAccrued));

      //   //log repay debt
      //   const debtRepaid = await poolContract.repayDebt(user2.address, 0);
      //   console.log("repaid debts", debtRepaid)

      //   expect(ethers.utils.formatEther(balanceAfter)).to.equal('0.0')
    })
  } catch (err) {
    console.log('err', err)
  }
})
