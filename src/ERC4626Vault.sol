// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC4626Vault is ERC4626, Ownable {
    uint256 public totalBorrowed; // Total the Diamond has borrowed
    uint256 public badDebt; // Total unrecoverable borrowed tokens
    uint256 public withdrawQueue; // Total amount currently queued to be withdrawn (locked)

    uint256 public constant COOLDOWN = 3 days;

    // Tracks each user’s pending withdrawal info
    struct WithdrawalRequest {
        uint256 amount; // Assets requested to withdraw
        uint256 cooldownEnd; // Timestamp when funds can be claimed
    }

    mapping(address => WithdrawalRequest) public pendingWithdrawals;

    event ProvidedLiquidity(address indexed provider, uint256 amount);
    event WithdrawnLiquidity(address indexed provider, uint256 amount);
    event Borrowed(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 amount);
    event AddBadDebt(address indexed diamond, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 cooldownEnd);
    event WithdrawalClaimed(address indexed claimer, address indexed receiver, uint256 amount);

    constructor(IERC20 _asset, string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC4626(_asset)
        Ownable(msg.sender) // The Diamond is the owner
    {}

    /// @notice Borrow underlying tokens from the vault
    function borrow(uint256 amount) external onlyOwner {
        require(amount <= availableLiquidity(), "Not enough available liquidity");
        totalBorrowed += amount;
        IERC20(asset()).transfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /// @notice Repay borrowed tokens
    function repay(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");

        bool success = IERC20(asset()).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        uint256 remaining = amount;

        // First repay totalBorrowed
        if (totalBorrowed > 0) {
            if (remaining >= totalBorrowed) {
                remaining -= totalBorrowed;
                totalBorrowed = 0;
            } else {
                totalBorrowed -= remaining;
                return; // all used up
            }
        }

        // Then repay badDebt
        if (badDebt > 0) {
            if (remaining >= badDebt) {
                remaining -= badDebt;
                badDebt = 0;
            } else {
                badDebt -= remaining;
                return; // all used up
            }
        }

        emit Repaid(msg.sender, amount);
        // If anything left, it stays in the contract, added to balanceOf naturally
    }

    // allows the protocol to add to the bad debt total for easy tracking
    function addBadDebt(uint256 _debt) external onlyOwner {
        badDebt += _debt;

        emit AddBadDebt(msg.sender, _debt);
    }

    /// @notice Initiate a withdrawal, starts cooldown, and locks funds
    /// @dev Shares are burned immediately, assets added to withdrawQueue until claimed
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        require(msg.sender == owner || allowance(owner, msg.sender) >= assets, "Not authorized");
        require(assets > 0, "Must withdraw > 0");

        receiver; //silence warning

        // Convert assets to shares and burn shares
        uint256 shares = previewWithdraw(assets);
        _burn(owner, shares);

        // Ensure user has no existing pending withdrawal
        require(pendingWithdrawals[owner].amount == 0, "Existing withdrawal pending");

        // Increase withdrawQueue by assets locked for withdrawal
        withdrawQueue += assets;

        // Record pending withdrawal with cooldown end timestamp
        pendingWithdrawals[owner] = WithdrawalRequest({amount: assets, cooldownEnd: block.timestamp + COOLDOWN});

        emit WithdrawalRequested(owner, assets, pendingWithdrawals[owner].cooldownEnd);

        // Receiver doesn't get funds now — they must call claimWithdraw after cooldown

        return shares;
    }

    /// @notice Redeem shares into assets (calls withdraw internally)
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        uint256 assets = convertToAssets(shares);
        return withdraw(assets, receiver, owner);
    }

    /// @notice Claim assets after cooldown period ends
    function claimWithdrawal(address receiver) external {
        WithdrawalRequest storage request = pendingWithdrawals[msg.sender];
        require(request.amount > 0, "No pending withdrawal");
        require(block.timestamp >= request.cooldownEnd, "Cooldown not ended");

        uint256 amount = request.amount;

        // Reset user's pending withdrawal
        delete pendingWithdrawals[msg.sender];

        // Reduce withdrawQueue by amount being claimed
        withdrawQueue -= amount;

        // Transfer tokens to user
        IERC20(asset()).transfer(receiver, amount);

        emit WithdrawalClaimed(msg.sender, receiver, amount);
    }

    /// @notice Total assets considering liquidity, borrowed amount, and bad debt
    function totalAssets() public view override returns (uint256) {
        return availableLiquidity() + totalBorrowed - badDebt;
    }

    /// @notice Available tokens in vault excluding queued withdrawals
    function availableLiquidity() public view returns (uint256) {
        uint256 bal = IERC20(asset()).balanceOf(address(this));
        return bal > withdrawQueue ? bal - withdrawQueue : 0;
    }

    /// @notice Max amount user can withdraw right now (always 0, withdrawals need cooldown)
    function maxWithdraw() public pure returns (uint256) {
        return 0;
    }

    function getCooldownEnd(address user) external view returns (uint256) {
        return pendingWithdrawals[user].cooldownEnd;
    }

    function getPendingWithdrawal(address user) external view returns (uint256 amount, uint256 cooldownEnd) {
        WithdrawalRequest storage request = pendingWithdrawals[user];
        return (request.amount, request.cooldownEnd);
    }
}
