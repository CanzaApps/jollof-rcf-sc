const { expect } = require('chai')
const { ethers } = require('hardhat')
const poolConfigData = require('../config/pool_config_data.json')

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
  
  function deposit() {

  }

  it('[PASS It should deposit', async ()=> {
    const [owner, user] = await ethers.getSigners();
    const balance = await busdContract.balanceOf(owner.address)
    console.log("owner balance", balance)
    await busdContract.connect(owner).approve(owner.address, ethers.utils.parseUnits('1000000', 'ether'))
    await busdContract.transferFrom(owner.address, user.address,  ethers.utils.parseUnits('100', 'ether'));
    const balance2 = await busdContract.balanceOf(user.address)
    console.log("balance", balance2)
    await busdContract.connect(user).approve(poolContractAddress, ethers.utils.parseUnits('1000000', 'ether'))
    await poolContract.connect(user).deposit(busdContract.address, ethers.utils.parseUnits('100', 'ether'));
    //Expects the user balance to be zero (0)
    const balanceAfter = await busdContract.balanceOf(user.address);
    expect(balanceAfter).to.equal(0);
  })
})
