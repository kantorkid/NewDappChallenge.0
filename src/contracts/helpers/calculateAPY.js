import { ethers } from "ethers";

export const getCompoundAPY = async (cWETHContract) => {
  // Reference -> https://compound.finance/docs#protocol-math

  const ethMantissa = ethers.BigNumber.from(1e18);
  const blocksPerDay = 6570; // 13.15 seconds per block
  const daysPerYear = 365;

  const supplyRatePerBlock = await cWETHContract.supplyRatePerBlock();
  const compAPY = supplyRatePerBlock
    .mul(blocksPerDay)
    .div(ethMantissa)
    .add(ethers.BigNumber.from(1))
    .pow(daysPerYear)
    .sub(ethers.BigNumber.from(1))
    .mul(ethMantissa);

  return compAPY;
};

export const getAaveAPY = async (aaveLendingPoolContract) => {
  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  const { currentLiquidityRate } = await aaveLendingPoolContract.getReserveData(
    WETH
  );
  const aaveAPY = ethers.BigNumber.from(currentLiquidityRate).div(
    ethers.BigNumber.from(1e7)
  );

  return aaveAPY;
};
