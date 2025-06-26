// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {RealEstateToken} from "./RealEstateToken.sol";
import {Roles} from "./Roles.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract Pool is Roles, ReentrancyGuard {

    error TokenIdNotFound();
    error InvalidProgramEnd();
    error PlanNotAssigned();  // 0xc4b1faa8
    error ProgramFinished();
    error NoFundsToWithdraw();  // 0x67e3990d
    error NoSafetyBalance(uint256);
    error TooShortEpoch();
    error NoRentToClaim();
    error MsgValueMismatch();
    error BalanceDepositMismatch();
    error NoEpochPrice(uint256);

    event RentPayment(uint256);
    event Claim(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 deposited, uint256 received, address token);
    event Withdraw(address indexed user, uint256 withdrawn, uint256 sent, address token);

    mapping(address appraiser => uint256) private s_claimed;

    struct UsagePlan {
        uint256 rentAmount;
        uint256 epochDuration;
        uint256 programEnd;
    }

    uint256 public constant APPRAISER_REWARD_SHARE = 50;
    uint256 public constant SAFETY_PERCENT = 10;
    uint256 private tokenId;
    uint256 private startTime;
    uint256 paidRent;
    uint256 public paymentDeposited;
    UsagePlan plan;

    RealEstateToken internal immutable i_realEstateToken;

    modifier planAssigned() {
        if (plan.epochDuration == 0) {
            revert PlanNotAssigned();
        }
        if (block.timestamp >= plan.programEnd) {
            revert ProgramFinished();
        }
        _;
    }

    constructor(address realEstateToken){
        i_realEstateToken = RealEstateToken(realEstateToken);
    }

    function assign(uint256 tokenId_, uint256 rentAmount_, uint256 epochDuration_, uint256 programEnd_) external payable nonReentrant onlyIssuerOrItself {
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
//        uint256 price = i_realEstateToken.getEpochPrice(tokenId_, 0);
//        uint256 safetyDeposit = price * i_realEstateToken.totalSupply(tokenId_) * SAFETY_PERCENT / 100;
//        if (msg.value !=safetyDeposit) {
//            console.log("Msg value: %s %s", msg.value, safetyDeposit);
//            revert MsgValueMismatch();
//        }
//        paymentDeposited += safetyDeposit;
        tokenId = tokenId_;
        plan = UsagePlan({
            rentAmount: rentAmount_,
            epochDuration: epochDuration_,
            programEnd: programEnd_
        });
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function getEpoch() public view planAssigned returns (uint256 epochNumber, uint256 epochEndTime) {
        uint256 nowTime = block.timestamp;
        epochNumber = ( nowTime - startTime ) / plan.epochDuration;
        epochEndTime = startTime + plan.epochDuration * (epochNumber + 1) - 1;
    }

    function rentDue() public view planAssigned returns (uint256 remainingRent) {
        uint256 nowTime = block.timestamp;
        uint256 totalRent = plan.rentAmount * ((nowTime - startTime) / plan.epochDuration + 1);
        remainingRent = totalRent - paidRent;
    }

    function safetyAmountDue() public view planAssigned returns (uint256 remainingAmount) {
        if (safetyAmount() > paymentDeposited) {
            return safetyAmount() - paymentDeposited;
        }
        return 0;
    }

    function payRent(uint256 amount) public payable nonReentrant planAssigned {
        if (msg.value != amount) {
            revert MsgValueMismatch();
        }
        paidRent += amount;
        emit RentPayment(amount);
    }

    function paySafety(uint256 amount) public payable nonReentrant planAssigned {
        if (msg.value != amount) {
            revert MsgValueMismatch();
        }
        paymentDeposited += amount;
        emit Deposit(msg.sender, amount, 0, address(i_realEstateToken));
    }

    function canLiquidate() public view planAssigned returns (bool) {
        return this.rentDue() > plan.rentAmount;
    }

    function getPlan() public view planAssigned returns (UsagePlan memory) {
        return plan;
    }

    function getPrice() public view planAssigned returns (uint256 tokenPrice) {
        uint256 epochNum = ( block.timestamp - startTime ) / plan.epochDuration;
        tokenPrice = i_realEstateToken.getEpochPrice(tokenId, epochNum);
    }

    function deposit(uint256 amountPayment) public payable nonReentrant planAssigned {
        if (msg.value != amountPayment) {
            revert MsgValueMismatch();
        }
        uint256 tokenPrice = this.getPrice();
        if (this.getPrice() == 0) {
            (uint256 epoch, ) = this.getEpoch();
            revert NoEpochPrice(epoch);
        }
        if (msg.value > 0) {
            uint256 amountRealEstate = amountPayment / tokenPrice;
            uint256 exactPayment = amountRealEstate * tokenPrice;
            i_realEstateToken.safeTransferFrom(address(this), msg.sender, tokenId, amountRealEstate, "");
            paymentDeposited += exactPayment;
            uint256 refund = amountPayment - exactPayment;
            if (refund > 0) {
                (bool success, ) = payable(msg.sender).call{value: refund}("");
                require(success, "Refund failed");
            }
            emit Deposit(msg.sender, exactPayment, amountRealEstate, address(i_realEstateToken));
        }
    }

    function safetyAmount() public view returns (uint256 paymentAmount) {
        uint256 totalSupply = i_realEstateToken.totalSupply(tokenId) * this.getPrice();
        return totalSupply * SAFETY_PERCENT / 100;
    }

    function availableWithdraw() public view returns (uint256 paymentAmount) {
        if (paymentDeposited <= this.safetyAmount()) {
            return 0;
        }
        return paymentDeposited - this.safetyAmount();
    }

    function withdraw(uint256 amountRealEstateToken) public nonReentrant {
        if (this.getPrice() == 0) {
            (uint256 epoch, ) = this.getEpoch();
            revert NoEpochPrice(epoch);
        }
        uint256 amountPayment = amountRealEstateToken * this.getPrice();
        if (amountPayment > availableWithdraw()) {
            revert NoFundsToWithdraw();
        }
        i_realEstateToken.safeTransferFrom(msg.sender, address(this), tokenId, amountRealEstateToken, "");
        (bool sent,) = payable(msg.sender).call{value: amountPayment}("");
        require(sent, "Withdraw failed");
        paymentDeposited -= amountPayment;
        emit Withdraw(msg.sender, amountPayment, amountRealEstateToken, address(i_realEstateToken));
    }

    function canClaimAppraiser(address appraiser) public view returns (uint256 rewards) {
        rewards = 0;
        (uint256 epoch, ) = getEpoch();
        for (uint256 i = 0; i < epoch; i++) {
            uint256 epochRewards = APPRAISER_REWARD_SHARE * plan.rentAmount / 100;
            rewards += epochRewards * i_realEstateToken.getRewardShare(appraiser, tokenId, i) / 1e18;
        }
        rewards -= s_claimed[appraiser];
    }

    function claim() public nonReentrant {
        uint256 amount = canClaimAppraiser(msg.sender);
        if (amount > paidRent) {
            revert NoRentToClaim();
        }
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Claim failed");
        paidRent -= amount;
        s_claimed[msg.sender] += amount;
        emit Claim(msg.sender, amount);
    }

}
