require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("solidity-coverage");


const { ALCHEMY_URL, PRIVATE_KEY } = process.env;

module.exports = {
  solidity: "0.8.18",
  networks: {
    sepolia: {
      url: ALCHEMY_URL,
      accounts: [PRIVATE_KEY],
    },
  },
};
