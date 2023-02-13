const { expect } = require('chai')
const { ethers } = require('hardhat')
const poolConfigData = require('../config/pool_config_data.json')
const { time } = require("@nomicfoundation/hardhat-network-helpers");

let poolConfigFactory
let poolConfigContract
let poolConfigContractAddress
let busdFactory
let busdContract
let busdContractAddress
let poolFactory
let poolContract
let poolContractAddress

describe('Pool Contarct', function () {
  beforeEach(async () => {
    const [owner] = await ethers.getSigners()
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
    poolContract = await poolFactory.deploy(15)
    poolContractAddress = poolContract.address;

    await poolContract.initPool(busdContract.address, poolConfigContract.address);
    await busdContract.mint(owner.address, "100000000000000000000000")

  })

  it('[PASS] It should initialize pool', async ()=> {
    const poolConfig = await poolContract.poolConfigs(busdContract.address)
     expect(poolConfig._token).to.equal(busdContractAddress.address)
     expect(poolConfig.status).to.equal(1)
  })
  
  async function deposit(amount, user) {
    const [owner] = await ethers.getSigners();
    const balance = await busdContract.balanceOf(owner.address)
    console.log("owner balance", balance)
    await busdContract.connect(owner).approve(owner.address, ethers.utils.parseUnits('1000000', 'ether'))
    await busdContract.transferFrom(owner.address, user.address,  ethers.utils.parseUnits('100', 'ether'));
    const balance2 = await busdContract.balanceOf(user.address)
    console.log("balance", balance2)
    await busdContract.connect(user).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))
    await poolContract.connect(user).deposit(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));
  }

  it('[PASS] It should deposit', async ()=> {
    const [_, user] = await ethers.getSigners();
    const amount = "100"
    await deposit(amount, user)
    //Expects user balance to zero(0) after depositing
    const balanceAfter = await busdContract.balanceOf(user.address);
    expect(balanceAfter).to.equal(0);
    const poolConfig = await poolContract.poolConfigs(busdContract.address)
    //Checks totalDeposit in the pool config  equals total amount deposited
    expect(poolConfig.totalDeposit).to.equal(ethers.utils.parseUnits(amount, 'ether'))
    const contractBalance = await busdContract.balanceOf(poolContract.address);
    expect(contractBalance).to.equal(ethers.utils.parseUnits(amount, 'ether'))
  })

  it('[PASS] it should borrow', async ()=> {
    const [_, user, user2] = await ethers.getSigners();
    const amount = "100"
    await deposit(amount, user);

    const userBalanceBefore = await busdContract.balanceOf(user.address);
    
    await poolContract.connect(user2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));

    const user2Balance = await busdContract.balanceOf(user2.address);
    //Excepts user2 balance to be 100
    expect(user2Balance).to.equal(ethers.utils.parseUnits(amount, 'ether'))

    const commitmentFee = await poolConfigContract.getCommitmentFee();
    const upFrontFee = ethers.utils.formatEther(commitmentFee) * +amount
    const debts = await poolContract.debts(user2.address, busdContractAddress)
    const amountBorrowed = debts.amountBorrowed;
    const debtAccrued = debts.debtAccrued;
    console.log("amount borrowed", amountBorrowed);
    console.log("upfront fee", upFrontFee)
    console.log("debt accrued", ethers.utils.formatEther(debtAccrued))
   // console.log("Poolconfig", debts);
  })

  it('[PASS] gets debt accrued', async() => {
    const [_, user1, user2] = await ethers.getSigners();
    const amount = "100"
    await deposit(amount, user1);
    await poolContract.connect(user2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));


    const userDebtAccrued = await poolContract.getUserDebtAccrued(busdContractAddress, user2.address);
    // console.log("user debt", ethers.utils.formatEther(userDebtAccrued));
    // await time.increase(3600);
    // const userDebtAccrued2 = await poolContract.getUserDebtAccrued(busdContractAddress, user2.address);
    // console.log("After 1 day", ethers.utils.formatEther(userDebtAccrued2));
   
  })

  it('[PASS] repay debt', async () => {
    const [_, user1, user2] = await ethers.getSigners();
    const amount = "100.0"
    await deposit(amount, user1);
    await poolContract.connect(user2).borrow(busdContract.address, ethers.utils.parseUnits(amount, 'ether'));

    //check balance before repaying debt
    const balanceBefore = await busdContract.balanceOf(user2.address);
    console.log("balance before,", ethers.utils.formatEther(balanceBefore));

    //Approve token
    await busdContract.connect(user2).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))

    expect(ethers.utils.formatEther(balanceBefore)).to.equal(amount)

    //Repy debt
    await poolContract.connect(user2).repay(busdContractAddress, ethers.utils.parseUnits(amount, 'ether'));

    //Check balance after
    const balanceAfter = await busdContract.balanceOf(user2.address);
    console.log("balance after", ethers.utils.formatEther(balanceAfter))

    const debts = await poolContract.debts(user2.address, busdContractAddress);
    const debtAccrued = debts.debtAccrued
    console.log("debt accrued", debts.debtAccrued)
    console.log("debts", ethers.utils.formatEther(debtAccrued));

    //log repay debt
    const debtRepaid = await poolContract.repayDebt(user2.address, 0);
    console.log("repaid debts", debtRepaid)

    expect(ethers.utils.formatEther(balanceAfter)).to.equal('0.0')


  })

})
