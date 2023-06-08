// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// Interface for ERC20 WETH contract
interface WETH {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

// Interfaces for Compound's cWETH contract and Aave's aWETH contract
interface cWETH {
    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

interface aWETH {
    function balanceOf(address account) external view returns (uint256);
}

// Interface for Aave's lending pool contract
interface AaveLendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external;

    function getReserveData(address asset)
        external
        returns (
            uint256 configuration,
            uint128 liquidityIndex,
            uint128 variableBorrowIndex,
            uint128 currentLiquidityRate,
            uint128 currentVariableBorrowRate,
            uint128 currentStableBorrowRate,
            uint40 lastUpdateTimestamp,
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress,
            address interestRateStrategyAddress,
            uint8 id
        );
}

contract Aggregator {
    using SafeMath for uint256;

    // Variables
    string public name = "Yield Aggregator";
    address public owner;
    address public locationOfFunds; // Keep track of where the user balance is stored
    uint256 public amountDeposited;

    WETH weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH contract address
    cWETH cWeth = cWETH(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5); // cWETH contract address
    aWETH aWeth = aWETH(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e); // aWETH contract address
    AaveLendingPool aaveLendingPool =
        AaveLendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    // Events
    event Deposit(address owner, uint256 amount, address depositTo);
    event Withdraw(address owner, uint256 amount, address withdrawFrom);
    event Rebalance(address owner, uint256 amount, address depositTo);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    // Constructor
    constructor() {
        owner = msg.sender;
    }

    // Functions

    function deposit(
        uint256 _amount,
        uint256 _compAPY,
        uint256 _aaveAPY
    ) public onlyOwner {
        require(_amount > 0, "Deposit amount must be greater than zero.");

        // Rebalance in the case of a protocol with the higher rate after their initial deposit,
        // is no longer the higher interest rate during this deposit...
        if (amountDeposited > 0) {
            rebalance(_compAPY, _aaveAPY);
        }

        weth.transferFrom(msg.sender, address(this), _amount);
        amountDeposited = amountDeposited.add(_amount);

        // Compare interest rates
        if (_compAPY > _aaveAPY) {
            // Deposit into Compound
            require(_depositToCompound(_amount) == 0, "Failed to deposit into Compound.");

            // Update location
            locationOfFunds = address(cWeth);
        } else {
            // Deposit into Aave
            _depositToAave(_amount);

            // Update location
            locationOfFunds = address(aaveLendingPool);
        }

        // Emit Deposit event
        emit Deposit(msg.sender, _amount, locationOfFunds);
    }

    function withdraw() public onlyOwner {
        require(amountDeposited > 0, "No funds available for withdrawal.");

        // Determine where the user funds are stored
        if (locationOfFunds == address(cWeth)) {
            require(_withdrawFromCompound() == 0, "Failed to withdraw from Compound.");
        } else {
            // Withdraw from Aave
            _withdrawFromAave();
        }

        // Once we have the funds, transfer back to owner
        uint256 balance = weth.balanceOf(address(this));
        weth.transfer(msg.sender, balance);

        emit Withdraw(msg.sender, amountDeposited, locationOfFunds);

        // Reset user balance
        amountDeposited = 0;
    }

    function rebalance(uint256 _compAPY, uint256 _aaveAPY) public onlyOwner {
        // Make sure funds are already deposited...
        require(amountDeposited > 0, "No funds available for rebalance.");

        uint256 balance;

        // Compare interest rates
        if ((_compAPY > _aaveAPY) && (locationOfFunds != address(cWeth))) {
            // If compoundRate is greater than aaveRate, and the current
            // location of user funds is not in compound, then we transfer funds.

            _withdrawFromAave();

            balance = weth.balanceOf(address(this));

            _depositToCompound(balance);

            // Update location
            locationOfFunds = address(cWeth);

            emit Rebalance(msg.sender, amountDeposited, locationOfFunds);
        } else if (
            (_aaveAPY > _compAPY) &&
            (locationOfFunds != address(aaveLendingPool))
        ) {
            // If aaveRate is greater than compoundRate, and the current
            // location of user funds is not in aave, then we transfer funds.

            _withdrawFromCompound();

            balance = weth.balanceOf(address(this));

            _depositToAave(balance);

            // Update location
            locationOfFunds = address(aaveLendingPool);

            emit Rebalance(msg.sender, amountDeposited, locationOfFunds);
        }
    }

    function _depositToCompound(uint256 _amount) internal returns (uint256) {
        require(weth.approve(address(cWeth), _amount), "Failed to approve WETH for Compound.");

        uint256 result = cWeth.mint(_amount);
        return result;
    }

    function _withdrawFromCompound() internal returns (uint256) {
        uint256 balance = cWeth.balanceOf(address(this));
        uint256 result = cWeth.redeem(balance);
        return result;
    }

    function _depositToAave(uint256 _amount) internal {
        require(weth.approve(address(aaveLendingPool), _amount), "Failed to approve WETH for Aave.");
        aaveLendingPool.deposit(address(weth), _amount, address(this), 0);
    }

    function _withdrawFromAave() internal {
        uint256 balance = aWeth.balanceOf(address(this));
        aaveLendingPool.withdraw(address(weth), balance, address(this));
    }

    // ---

    function balanceOfContract() public view returns (uint256) {
        if (locationOfFunds == address(cWeth)) {
            return cWeth.balanceOf(address(this));
        } else {
            return aWeth.balanceOf(address(this));
        }
    }

    function balanceWhere() public view returns (address) {
        return locationOfFunds;
    }
}
