const { expect } = require("chai");

describe("Aggregator", function () {
  let Aggregator;
  let aggregator;
  let weth;
  let cWETH;
  let aWETH;
  let aaveLendingPool;

  let owner;
  let user2;

  beforeEach(async function () {
    Aggregator = await ethers.getContractFactory("Aggregator");

    [owner, user2] = await ethers.getSigners();

    weth = await ethers.getContractAt(
      "WETH",
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    ); // Replace with the deployed WETH contract address
    cWETH = await ethers.getContractAt(
      "cWETH",
      "0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5"
    ); // Replace with the deployed cWETH contract address
    aWETH = await ethers.getContractAt(
      "aWETH",
      "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e"
    ); // Replace with the deployed aWETH contract address
    AaveLendingPool = await ethers.getContractAt(
      "AaveLendingPool",
      "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
    ); // Replace with the deployed aave Lending Pool contract address

    aggregator = await Aggregator.deploy();
    await aggregator.deployed();
  });

  describe("deployment", function () {
    it("passes the smoke test", async function () {
      expect(await aggregator.name()).to.equal("Yield Aggregator");
    });
  });

  describe("exchange rates", function () {
    it("fetches compound exchange rate", async function () {
      // Fetch compound exchange rate
      const compAPY = await aggregator.getCompoundAPY(cWETH.address);
      console.log(compAPY.toString());
      expect(compAPY).to.not.equal(0);
    });

    it("fetches aave exchange rate", async function () {
      // Fetch Aave exchange rate
      const aaveAPY = await aggregator.getAaveAPY(aaveLendingPool.address);
      console.log(aaveAPY.toString());
      expect(aaveAPY).to.not.equal(0);
    });
  });

  describe("deposits", function () {
    let amount = 10;
    let amountInWei = ethers.utils.parseEther(amount.toString());
    let compAPY, aaveAPY;
    let result;

    describe("success", function () {
      beforeEach(async function () {
        // Fetch compound exchange rate
        compAPY = await aggregator.getCompoundAPY(cWeth.address);

        // Fetch Aave exchange rate
        aaveAPY = await aggregator.getAaveAPY(aaveLendingPool.address);

        // Approve WETH transfer to aggregator
        await weth.connect(owner).approve(aggregator.address, amountInWei);

        // Deposit WETH to aggregator
        result = await aggregator
          .connect(owner)
          .deposit(amountInWei, compAPY, aaveAPY);
      });

      it("tracks the WETH amount", async function () {
        // Check WETH balance in the aggregator
        const balance = await aggregator.amountDeposited();
        expect(balance).to.equal(amountInWei);
      });

      it("tracks where WETH is stored", async function () {
        const locationOfFunds = await aggregator.balanceWhere();
        console.log(locationOfFunds);
      });

      it("emits deposit event", async function () {
        const receipt = await result.wait();
        const log = receipt.events.find((event) => event.event === "Deposit");
        expect(log).to.not.be.undefined;
      });
    });

    describe("failure", function () {
      it("fails when transfer is not approved", async function () {
        await expect(
          aggregator.connect(owner).deposit(amountInWei, compAPY, aaveAPY)
        ).to.be.revertedWith(
          "VM Exception while processing transaction: revert"
        );
      });

      it("fails when amount is 0", async function () {
        await expect(
          aggregator.connect(owner).deposit(0, compAPY, aaveAPY)
        ).to.be.revertedWith(
          "VM Exception while processing transaction: revert"
        );
      });
    });
  });

  describe("withdraws", function () {
    let amount = 10;
    let amountInWei = ethers.utils.parseEther(amount.toString());
    let compAPY, aaveAPY;
    let result;

    describe("success", function () {
      beforeEach(async function () {
        // Fetch compound exchange rate
        compAPY = await aggregator.getCompoundAPY(cWeth.address);

        // Fetch Aave exchange rate
        aaveAPY = await aggregator.getAaveAPY(aaveLendingPool.address);

        // Approve WETH transfer to aggregator
        await weth.connect(owner).approve(aggregator.address, amountInWei);

        // Deposit WETH to aggregator
        await aggregator.connect(owner).deposit(amountInWei, compAPY, aaveAPY);

        // Withdraw WETH from aggregator
        result = await aggregator.connect(owner).withdraw();
      });

      it("emits withdraw event", async function () {
        const receipt = await result.wait();
        const log = receipt.events.find((event) => event.event === "Withdraw");
        expect(log).to.not.be.undefined;
      });

      it("updates the user contract balance", async function () {
        const balance = await aggregator.amountDeposited();
        expect(balance).to.equal(ethers.constants.Zero);
      });
    });

    describe("failure", function () {
      it("fails if user has no balance", async function () {
        await expect(aggregator.connect(owner).withdraw()).to.be.revertedWith(
          "VM Exception while processing transaction: revert"
        );
      });

      it("fails if a different user attempts to withdraw", async function () {
        await expect(aggregator.connect(user2).withdraw()).to.be.revertedWith(
          "VM Exception while processing transaction: revert"
        );
      });
    });
  });

  describe("rebalance", function () {
    let compAPY, aaveAPY;

    describe("failure", function () {
      beforeEach(async function () {
        // Fetch compound exchange rate
        compAPY = await aggregator.getCompoundAPY(cWeth.address);

        // Fetch Aave exchange rate
        aaveAPY = await aggregator.getAaveAPY(aaveLendingPool.address);
      });

      it("fails if user has no balance", async function () {
        await expect(
          aggregator.connect(owner).rebalance(compAPY, aaveAPY)
        ).to.be.revertedWith(
          "VM Exception while processing transaction: revert"
        );
      });
    });
  });
});
