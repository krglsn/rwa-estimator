// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {RealEstateToken} from "./RealEstateToken.sol";
import {Roles} from "./Roles.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract Pool is Roles, ReentrancyGuard {
    error TokenIdNotFound();
    error InvalidProgramEnd();
    error PlanNotAssigned(); // 0xc4b1faa8
    error PlanAlreadyAssigned();
    error ProgramFinished();
    error ProgramNotFinished();
    error NoFundsToWithdraw(); // 0x67e3990d
    error NoSafetyBalance(uint256);
    error TooShortEpoch();
    error NoRentToClaim();
    error MsgValueMismatch();
    error BalanceDepositMismatch();
    error NoEpochPrice(uint256);
    error NoEnoughBalance();
    error NotAssetOwner();
    error LowLiquidationPayment();
    error CannotLiquidate();
    error RentUnpaid();

    event RentPayment(uint256);
    event Claim(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 deposited, uint256 received, address token);
    event Withdraw(address indexed user, uint256 withdrawn, uint256 sent, address token);
    event Liquidation(address indexed oldOwner, address indexed newOwner);

    mapping(address appraiser => uint256) private s_claimed;
    mapping(address depositor => uint256) private s_claimedDepositor;
    mapping(address => mapping(uint256 => int256)) private s_userEpochRealEstateDeltas;
    mapping(address => uint256[]) private s_userActiveEpochs;

    struct UsagePlan {
        uint256 rentAmount;
        uint256 epochDuration;
        uint256 programEnd;
    }

    // Rent payments are split for rewards to Appraisers and Depositors
    uint256 public constant APPRAISER_REWARD_SHARE = 50;

    // Pool has safety margin of deposited funds that cannot be withdrawn till program end
    uint256 public constant SAFETY_PERCENT = 10;

    uint256 private tokenId;
    uint256 private startTime;
    uint256 paidRent;
    uint256 public paymentDeposited;
    UsagePlan plan;

    RealEstateToken internal immutable i_realEstateToken;

    modifier planActive() {
        if (plan.epochDuration == 0) {
            revert PlanNotAssigned();
        }
        if (block.timestamp >= plan.programEnd) {
            revert ProgramFinished();
        }
        _;
    }

    modifier planAssigned() {
        if (plan.epochDuration == 0) {
            revert PlanNotAssigned();
        }
        _;
    }

    modifier onlyAssetOwner() {
        if (!i_realEstateToken.isAssetOwner(tokenId, msg.sender)) {
            revert NotAssetOwner();
        }
        _;
    }

    constructor(address realEstateToken) {
        i_realEstateToken = RealEstateToken(realEstateToken);
    }

    /**
     * @notice Assign payment plan to tokenId
     * @dev
     * @param tokenId_ ERC1155 tokenId to associate this pool with
     * @param rentAmount_ Amount to pay rent per single payment interval
     * @param epochDuration_ Payment interval
     * @param programEnd_ End of rent obligations
     */
    function assign(uint256 tokenId_, uint256 rentAmount_, uint256 epochDuration_, uint256 programEnd_)
        external
        payable
        nonReentrant
        onlyIssuerOrItself
    {
        if (plan.epochDuration != 0) {
            revert PlanAlreadyAssigned();
        }
        if (!i_realEstateToken.exists(tokenId_)) {
            revert TokenIdNotFound();
        }
        if (epochDuration_ < i_realEstateToken.APPRAISAL_LOCK_TIME()) {
            revert TooShortEpoch();
        }
        uint256 start = block.timestamp;
        paidRent = 0;
        startTime = block.timestamp;
        if (start >= programEnd_) {
            revert InvalidProgramEnd();
        }
        tokenId = tokenId_;
        plan = UsagePlan({rentAmount: rentAmount_, epochDuration: epochDuration_, programEnd: programEnd_});
    }

    /**
     * @notice Generic function to support ERC1155 transfers
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Get current epoch info
     * @return epochNumber
     * @return epochEndTime last timestamp of current epoch
     */
    function getEpoch() public view planAssigned returns (uint256 epochNumber, uint256 epochEndTime) {
        uint256 nowTime = block.timestamp;
        epochNumber = (nowTime - startTime) / plan.epochDuration;
        epochEndTime = startTime + plan.epochDuration * (epochNumber + 1) - 1;
    }

    /**
     * @notice Get rent amount to be paid in current epoch
     */
    function rentDue() public view planAssigned returns (uint256 remainingRent) {
        uint256 nowTime = block.timestamp;
        uint256 totalRent = plan.rentAmount * ((nowTime - startTime) / plan.epochDuration + 1);
        remainingRent = totalRent - paidRent;
    }

    /**
     * @notice Get amount to keep safety margin in current epoch, depends on current pricing.
     */
    function safetyAmountDue() public view planActive returns (uint256 remainingAmount) {
        if (safetyAmount() > paymentDeposited) {
            return safetyAmount() - paymentDeposited;
        }
        return 0;
    }

    /**
     * @notice Pay rent
     * @param amount could be any, but see rentDue() also
     */
    function payRent(uint256 amount) public payable nonReentrant planAssigned {
        if (msg.value != amount) {
            revert MsgValueMismatch();
        }
        paidRent += amount;
        emit RentPayment(amount);
    }

    /**
     * @notice pay deposit to increase safety margin
     * @param amount could be any but see also SafetyAmountDue
     */
    function paySafety(uint256 amount) public payable nonReentrant planActive {
        if (msg.value != amount) {
            revert MsgValueMismatch();
        }
        paymentDeposited += amount;
        emit Deposit(msg.sender, amount, 0, address(i_realEstateToken));
    }

    /**
     * @notice Check if asset could be liquidated (transfered to another owner)
     * @dev assed is liquidable if rent payment interval missed
     * @dev TODO: liquidation condition could be more complex and involve safety deposit also
     */
    function canLiquidate() public view planAssigned returns (bool) {
        return this.rentDue() > plan.rentAmount;
    }

    /**
     * @notice function to transfer asset ownership by paying rent and safety debts
     * @dev This function not implemented due to time restrictions.
     * @dev Basically it should involve more roles and simply transfer ownership
     * @dev when rent and safety debts are paid.
     */
    function liquidate() public payable nonReentrant planAssigned {
        if (!canLiquidate()) {
            revert CannotLiquidate();
        }
        uint256 paymentRent = rentDue();
        uint256 paymentSafety = safetyAmountDue();
        uint256 paymentRequired = paymentRent + paymentSafety;
        if (msg.value < paymentRequired) {
            revert LowLiquidationPayment();
        }
        paidRent += paymentRent;
        emit RentPayment(paymentRent);
        paymentDeposited += paymentSafety;
        emit Deposit(msg.sender, paymentSafety, 0, address(i_realEstateToken));
        i_realEstateToken.setAssetOwner(tokenId, msg.sender);
        emit Liquidation(i_realEstateToken.owner(), msg.sender);
    }

    /**
     * @notice get parameters of plan associated with this pool.
     */
    function getPlan() public view planAssigned returns (UsagePlan memory) {
        return plan;
    }

    /**
     * @notice Get current weighted price at the current epoch.
     */
    function getPrice() public view planAssigned returns (uint256 tokenPrice) {
        tokenPrice = 0;
        uint256 epochNum = (block.timestamp - startTime) / plan.epochDuration;
        tokenPrice = i_realEstateToken.getEpochPrice(tokenId, epochNum);
        if (tokenPrice == 0 && epochNum > 0) {
            for (uint256 i = epochNum - 1; i < epochNum; i--) {
                uint256 prevPrice = i_realEstateToken.getEpochPrice(tokenId, i);
                if (prevPrice > 0) {
                    tokenPrice = prevPrice;
                    break;
                }
                if (i == 0) {
                    break;
                }
            }
        }
    }

    function _recordBalanceChange(address user, uint256 epoch, int256 delta) private {
        if (s_userEpochRealEstateDeltas[user][epoch] == 0) {
            s_userActiveEpochs[user].push(epoch);
        }
        s_userEpochRealEstateDeltas[user][epoch] += delta;
    }

    /**
     * @notice Get user (depositor) token balance at specific epoch.
     */
    function getUserBalanceAtEpoch(address user, uint256 targetEpoch) public view returns (uint256) {
        int256 cumulativeBalance = 0;
        for (uint256 i = 0; i < s_userActiveEpochs[user].length; i++) {
            uint256 epoch = s_userActiveEpochs[user][i];
            if (epoch <= targetEpoch) {
                cumulativeBalance += s_userEpochRealEstateDeltas[user][epoch];
            }
        }
        return cumulativeBalance > 0 ? uint256(cumulativeBalance) : 0;
    }

    /**
     * @notice Deposit Native token into contract and get corresponding Token amount.
     * @param amountPayment native amount, actual payment will be rounded per Token current price.
     */
    function deposit(uint256 amountPayment) public payable nonReentrant {
        if (msg.value != amountPayment) {
            revert MsgValueMismatch();
        }
        uint256 tokenPrice = this.getPrice();
        if (this.getPrice() == 0) {
            (uint256 epoch,) = this.getEpoch();
            revert NoEpochPrice(epoch);
        }
        if (msg.value > 0) {
            (uint256 epochId,) = this.getEpoch();
            uint256 amountRealEstate = amountPayment / tokenPrice;
            uint256 exactPayment = amountRealEstate * tokenPrice;
            i_realEstateToken.safeTransferFrom(address(this), msg.sender, tokenId, amountRealEstate, "");
            _recordBalanceChange(msg.sender, epochId, int256(amountRealEstate));
            paymentDeposited += exactPayment;
            uint256 refund = amountPayment - exactPayment;
            if (refund > 0) {
                (bool success,) = payable(msg.sender).call{value: refund}("");
                require(success, "Refund failed");
            }
            emit Deposit(msg.sender, exactPayment, amountRealEstate, address(i_realEstateToken));
        }
    }

    /**
     * @notice Get value of total safetyAmount required to be in pool.
     * @dev see also safetyAmountDue()
     */
    function safetyAmount() public view returns (uint256 paymentAmount) {
        uint256 totalSupplyValue = i_realEstateToken.totalSupply(tokenId) * getPrice();
        return totalSupplyValue * SAFETY_PERCENT / 100;
    }

    /**
     * @notice total native amount available to withdraw from pool by owner.
     * @dev this is also the limit for depositors to take out.
     */
    function availableWithdraw() public view returns (uint256 paymentAmount) {
        if (paymentDeposited <= safetyAmount()) {
            return 0;
        }
        return paymentDeposited - safetyAmount();
    }

    /**
     * @notice withdraw native token from pool by owner, with respect to safetyDeposit.
     * @dev TODO: emergence withdraw should be implemented separately.
     */
    function withdrawOwner(uint256 amountPayment) public nonReentrant onlyAssetOwner planActive {
        if (amountPayment > availableWithdraw()) {
            revert NoFundsToWithdraw();
        }
        (bool sent,) = payable(msg.sender).call{value: amountPayment}("");
        require(sent, "Withdraw failed");
        paymentDeposited -= amountPayment;
        emit Withdraw(msg.sender, amountPayment, 0, address(i_realEstateToken));
    }

    /**
     * @notice deposit (repay) native token by owner.
     */
    function depositOwner(uint256 amount) public payable nonReentrant onlyAssetOwner {
        if (msg.value != amount) {
            revert MsgValueMismatch();
        }
        paymentDeposited += amount;
        emit Deposit(msg.sender, amount, 0, address(i_realEstateToken));
    }

    /**
     * @notice Burn tokens on contract, only possible after program end.
     * @dev If depositors hold part of tokens then some ETH amount will remain in contract.
     */
    function closeProgram() public nonReentrant onlyAssetOwner {
        if (block.timestamp < plan.programEnd) {
            revert ProgramNotFinished();
        }
        if (rentDue() > 0) {
            revert RentUnpaid();
        }
        uint256 poolBalance = i_realEstateToken.balanceOf(address(this), tokenId);
        i_realEstateToken.burn(address(this), tokenId, poolBalance);
    }

    /**
     * @notice withdraw native token from pool by swapping Token
     * @dev approval should be set to Token prior to this call
     * @param amountRealEstateToken token amount that user wants to swap back to native.
     */
    function withdraw(uint256 amountRealEstateToken) public nonReentrant {
        uint256 price = getPrice();
        if (price == 0) {
            (uint256 epoch,) = this.getEpoch();
            revert NoEpochPrice(epoch);
        }
        if (amountRealEstateToken > i_realEstateToken.balanceOf(msg.sender, tokenId)) {
            revert NoEnoughBalance();
        }
        uint256 amountPayment = amountRealEstateToken * price;
        if (amountPayment > availableWithdraw()) {
            revert NoFundsToWithdraw();
        }
        (uint256 epochId,) = getEpoch();
        i_realEstateToken.safeTransferFrom(msg.sender, address(this), tokenId, amountRealEstateToken, "");
        (bool sent,) = payable(msg.sender).call{value: amountPayment}("");
        require(sent, "Withdraw failed");
        _recordBalanceChange(msg.sender, epochId, -int256(amountRealEstateToken));
        paymentDeposited -= amountPayment;
        emit Withdraw(msg.sender, amountPayment, amountRealEstateToken, address(i_realEstateToken));
    }

    /**
     * @notice how much can claim Appraiser by current epoch
     */
    function canClaimAppraiser(address appraiser) public view returns (uint256 rewards) {
        rewards = 0;
        (uint256 epoch,) = getEpoch();
        for (uint256 i = 0; i < epoch; i++) {
            uint256 epochRewards = APPRAISER_REWARD_SHARE * plan.rentAmount / 100;
            rewards += epochRewards * i_realEstateToken.getRewardShare(appraiser, tokenId, i) / 1e18;
        }
        rewards -= s_claimed[appraiser];
    }

    /**
     * @notice how much can claim Depositor by current epoch
     */
    function canClaimDepositor(address depositor) public view returns (uint256) {
        (uint256 currentEpoch,) = getEpoch();
        uint256 totalClaimable = 0;
        uint256 totalSupply = i_realEstateToken.totalSupply(tokenId);
        require(totalSupply > 0, "Zero total supply");
        for (uint256 epoch = 1; epoch < currentEpoch; epoch++) {
            uint256 userBalance = getUserBalanceAtEpoch(depositor, epoch);
            if (userBalance == 0) {
                continue;
            }
            uint256 userShare = (userBalance * 1e18) / totalSupply;
            uint256 epochClaimable = (plan.rentAmount * userShare) / 1e18;
            totalClaimable += epochClaimable;
        }
        uint256 alreadyClaimed = s_claimedDepositor[depositor];
        if (totalClaimable <= alreadyClaimed) {
            return 0;
        }
        return totalClaimable - alreadyClaimed;
    }

    /**
     * @notice claim rewards as Appraiser
     */
    function claimAppraiser() public nonReentrant {
        uint256 amount = canClaimAppraiser(msg.sender);
        if (amount > paidRent) {
            revert NoRentToClaim();
        }
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "Claim failed");
        paidRent -= amount;
        s_claimed[msg.sender] += amount;
        emit Claim(msg.sender, amount);
    }

    /**
     * @notice claim rewards as Depositor
     */
    function claimDepositor() public nonReentrant {
        uint256 amount = canClaimDepositor(msg.sender);
        if (amount > paidRent) {
            revert NoRentToClaim();
        }
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "Claim failed");
        paidRent -= amount;
        s_claimedDepositor[msg.sender] += amount;
        emit Claim(msg.sender, amount);
    }
}
