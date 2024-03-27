/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-web3");
require("solidity-coverage");
require("hardhat-deploy");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-solhint");
require("hardhat-spdx-license-identifier");
require("hardhat-docgen");
require("@nomiclabs/hardhat-etherscan");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-contract-sizer");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
 const fs = require('fs')
 //const privateKey = fs.readFileSync('.secrete').toString()
 const RINKEBY_RPC_URL = "https://rinkeby.infura.io/v3/b4074d04e5e947208fa8b8b601ee57bf";
const PRIVATE_KEY = "4cacfec187b1b89b13e888784697c86de3cdb2c79b318777e92ebcfea52bef43";
const ALFAJORES_URL = "https://alfajores-forno.celo-testnet.org"
module.exports = {
  networks:{
    hardhat:{
        chainId: 1377
      },
      alfajores:{
        url:ALFAJORES_URL,
        accounts:[PRIVATE_KEY],
        chainId: 44787
      },
      mainnet:{
        url:"https://polygon-mainnet.infura.io/v3/33de597949e847ecbea3575de71646ba",
        accounts:[PRIVATE_KEY]
      },
      fuji: {
        url: "https://api.avax-test.network/ext/bc/C/rpc",
        gasPrice: 225000000000,
        chainId: 43113,
        accounts: [PRIVATE_KEY],
      }
    },

  solidity:{
    compilers: [
      {
        version: "0.8.20",
      },
      {
        version: "0.8.7",
        settings: {},
      },
    ],
  },
  // networks: {
  //   fuji: {
  //     url: "https://api.avax-test.network/ext/bc/C/rpc",
  //     gasPrice: 225000000000,
  //     chainId: 43113,
  //     accounts: [PRIVATE_KEY],
  //   }
  // }
};
//0xd70e0c161B053114705f212a593f13B97b3fbb7f