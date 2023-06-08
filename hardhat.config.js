require("@nomiclabs/hardhat-ethers"); // Add this line
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  solidity: "0.8.4",
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/ZU30YcVCbwi9w4xnNUeYvu_lrWe8eDyi",
      },
    },
  },
  etherscan: {
    apiKey: "1M1I9PGVCQSEJI5HD13KIUVPTUB61XY6QE",
  },
};
