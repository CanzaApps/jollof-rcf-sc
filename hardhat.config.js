/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("@nomiclabs/hardhat-waffle");
 require("@nomiclabs/hardhat-ethers");
 const fs = require('fs')
 //const privateKey = fs.readFileSync('.secrete').toString()
 const RINKEBY_RPC_URL = "https://rinkeby.infura.io/v3/b4074d04e5e947208fa8b8b601ee57bf";
const PRIVATE_KEY = "";
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
      }
    },

  solidity:{
    compilers: [
      {
        version: "0.8.9",
      },
      {
        version: "0.8.7",
        settings: {},
      },
    ],
  }
};
//0xd70e0c161B053114705f212a593f13B97b3fbb7f