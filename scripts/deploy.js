// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require('hardhat')
const poolConfigData = require('../config/pool_config_data.json')

async function main() {
  const [deployer] = await ethers.getSigners()
  console.log('Deploying contracts with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  //Deploy pool configuration
  const PoolConfig = await ethers.getContractFactory('PoolConfiguration')
  const config = poolConfigData['USDT']
  const poolConfig = await PoolConfig.deploy(
    config.interestRate,
    config.commitmentFee,
    config.commitmentAmountUsdValue,
    config.durationOfCommitmentAgreementInDays,
    config.upfrontFee,
    config.penaltyRate,
    config.protocolFee
  )
  console.log("pool config contract", poolConfig.address);


  //Deploy mock token
  const MockToken = await ethers.getContractFactory('BUSDToken');
  const tokenContract = await MockToken.deploy();
  console.log("token address", tokenContract.address)

  //Deploy pool
  const Pool = await ethers.getContractFactory('Pool')
  const poolContract = await Pool.deploy()
  console.log("pool contract", poolContract.address);
  await poolContract.initPool(tokenContract.address,poolConfig.address)

  //mint token
  //const mint = await tokenContract.methods.mint(deployer.address, "100000000000000000000000").send({ from: address })
 
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
