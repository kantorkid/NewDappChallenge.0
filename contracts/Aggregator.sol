// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

// Interface for ERC20 WETH contract
interface WETH {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function balanceOf(address) external view returns (uint256);
}

// Interface for Compound's cWETH contract
interface cWETH {
    function mint(uint256) external returns (uint256);

    function redeem(uint256) external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function balanceOf(address) external view returns (uint256);
}

interface aWETH {
    function balanceOf(address) external view returns (uint256);
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
    // Variables
    string public name = "Yield Aggregator";
    address public owner;
    address public locationOfFunds; // Keep track of where the user balance is stored
    uint256 public amountDeposited;

    // Define WETH contract
    WETH weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // Define cWETH contract from Compound
    cWETH cWeth = cWETH(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    // Define aWETH contract from Aave
    aWETH aWeth = aWETH(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
    // Define Aave lending pool
    AaveLendingPool aaveLendingPool = AaveLendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    // Events
    event Deposit(address owner, uint256 amount, address depositTo);
    event Withdraw(address owner, uint256 amount, address withdrawFrom);
    event Rebalance(address owner, uint256 amount, address depositTo);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    // Constructor
    constructor(address _owner) {
        owner = _owner;
        console.log("Constructor initialized with owner: %s", owner);
    }

    // Functions
    function deposit(
        uint256 _amount,
        uint256 _compAPY,
        uint256 _aaveAPY
    ) public onlyOwner {
        console.log(
            "Depositing %s tokens with Compound APY: %s and Aave APY: %s",
            _amount,
            _compAPY,
            _aaveAPY
        );
        require(_amount > 0, "Amount must be greater than 0.");

        if (amountDeposited > 0) {
            console.log("Rebalancing before depositing");
            rebalance(_compAPY, _aaveAPY);
        }

        console.log("Transfering tokens from %s to the contract", msg.sender);
        weth.transferFrom(msg.sender, address(this), _amount);
        amountDeposited = amountDeposited + _amount;

        if (_compAPY > _aaveAPY) {
            console.log("Depositing to Compound");
            require(_depositToCompound(_amount) == 0, "Deposit to Compound failed.");

            locationOfFunds = address(cWeth);
        } else {
            console.log("Depositing to Aave");
            _depositToAave(_amount);

            locationOfFunds = address(aaveLendingPool);
        }

        emit Deposit(msg.sender, _amount, locationOfFunds);
    }

    function withdraw() public onlyOwner {
        console.log("Entering withdraw function");
        require(amountDeposited > 0, "No funds to withdraw.");

        // Determine where the user funds are stored
        if (locationOfFunds == address(cWeth)) {
            require(_withdrawFromCompound() == 0, "Withdraw from Compound failed.");
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
        console.log(
            "Entering rebalance function with Compound APY: %s and Aave APY: %s",
            _compAPY,
            _aaveAPY
        );
        // Make sure funds are already deposited...
        require(amountDeposited > 0, "No funds to rebalance.");

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
        } else if ((_aaveAPY > _compAPY) && (locationOfFunds != address(aaveLendingPool))) {
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

    function _depositToCompound(uint256 _amount) private returns (uint) {
        console.log("Approving Compound to spend tokens");
        // Approve Compound cToken contract to move your DAI
        weth.approve(address(cWeth), _amount);

        console.log("Minting cTokens");
        // Mint cTokens
        return cWeth.mint(_amount);
    }

    function _withdrawFromCompound() internal returns (uint256) {
        uint256 balance = cWeth.balanceOf(address(this));

        console.log("Withdrawing from Compound:", balance);

        uint256 result = cWeth.redeem(balance);
        return result;
    }

    function _depositToAave(uint256 _amount) private {
        console.log("Approving Aave to spend tokens");
        // Approve Aave LendingPool contract to move your DAI
        weth.approve(address(aaveLendingPool), _amount);

        console.log("Depositing to Aave");
        // Call deposit function on Aave LendingPool
        aaveLendingPool.deposit(address(weth), _amount, address(this), 0);
    }

    function _withdrawFromAave() internal {
        console.log("Entering _withdrawFromAave function");
        uint256 balance = aWeth.balanceOf(address(this));

        console.log("Withdrawing from Aave:", balance);

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
