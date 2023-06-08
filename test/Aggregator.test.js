// test/DAIBalance.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Import the IERC20 interface from OpenZeppelin Contracts
const { utils } = ethers;
const { BigNumber } = ethers;
const IERC20 = require("@openzeppelin/contracts/build/contracts/IERC20.json");

describe("DAI Balance", function () {
  it("Should have the right DAI balance", async function () {
    const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f"; // DAI token address on Ethereum mainnet
    const signer = (await ethers.getSigners())[0];
    const address = await signer.getAddress();
    const daiToken = await ethers.getContractAt(IERC20.abi, DAI_ADDRESS);
    const balance = await daiToken.balanceOf(address);
    console.log("DAI balance:", balance.toString());

    // Add an assertion here if you want to check the balance
    // expect(balance).to.equal(BigNumber.from("100"));
  });
});

describe("WETH Balance", function () {
  it("Should have the right WETH balance", async function () {
    const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH token address on Ethereum mainnet
    const signer = (await ethers.getSigners())[0];
    const address = await signer.getAddress();
    const wethToken = await ethers.getContractAt(IERC20.abi, WETH_ADDRESS);
    const balance = await wethToken.balanceOf(address);
    console.log("WETH balance:", balance.toString());

    // Add an assertion here if you want to check the balance
    // expect(balance).to.equal(BigNumber.from("100"));
  });
});

describe("ETH Balance", function () {
  it("Should have the right ETH balance", async function () {
    const signer = (await ethers.getSigners())[0];
    const address = await signer.getAddress();
    const balance = await ethers.provider.getBalance(address);
    console.log("ETH balance:", balance.toString());

    // Add an assertion here if you want to check the balance
    // expect(balance).to.equal(expectedBalance);
  });
});

describe("Aggregator", function () {
  let Aggregator;
  let aggregator;
  let owner;
  let anotherAccount;

  beforeEach(async function () {
    Aggregator = await ethers.getContractFactory("Aggregator");

    [owner, anotherAccount] = await ethers.getSigners();

    // Deploy the contract from owner account
    aggregator = await Aggregator.connect(owner).deploy(owner.address);
    await aggregator.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const actualOwner = await aggregator.owner();
      expect(actualOwner).to.equal(owner.address);
    });
  });

  describe("Transactions", function () {
    it("Should deposit WETH to the right platform", async function () {
      const amount = ethers.utils.parseEther("1"); // deposit 1 WETH
      const compAPY = 1000; // some value for Compound APY
      const aaveAPY = 900; // some value for Aave APY
      await aggregator.connect(owner).deposit(amount, compAPY, aaveAPY);
      // Add your own checks here
    });

    it("Should rebalance WETH from Compound to Aave", async function () {
      const compAPY = 900; // some value for Compound APY
      const aaveAPY = 1000; // some value for Aave APY
      await aggregator.connect(owner).rebalance(compAPY, aaveAPY);
      // Add your own checks here
    });

    it("Should allow withdrawal of deposited WETH", async function () {
      await aggregator.connect(owner).withdraw();
      // Add your own checks here
    });

    it("Should fail when a non-owner tries to deposit", async function () {
      const amount = ethers.utils.parseEther("1"); // deposit 1 WETH
      const compAPY = 1000; // some value for Compound APY
      const aaveAPY = 900; // some value for Aave APY
      await expect(
        aggregator.connect(anotherAccount).deposit(amount, compAPY, aaveAPY)
      ).to.be.revertedWith("Only the owner can call this function.");
    });
  });
});
