// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {RealEstateToken} from "./RealEstateToken.sol";
import {OwnerIsCreator} from "lib/chainlink-evm/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";


contract Pool is OwnerIsCreator {

    error TokenIdNotFound();
    error NotIssuerOrItself(address);
    error InvalidProgramEnd();
    error PlanNotAssigned();
    error ProgramFinished();
    error NoFundsToWithdraw();
    error NoSafetyBalance(uint256);

    event RentPayment(uint256);

    event SetIssuer(address indexed issuer);
    event Deposit(address indexed depositor, uint256 depositAmount, uint256 receiveAmount);

    struct UsagePlan {
        uint256 rentAmount;
        uint256 epochDuration;
        uint256 programEnd;
    }


    uint256 public constant SAFETY_PERCENT = 10;
    address s_issuer;
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

    modifier onlyIssuerOrItself() {
        if (msg.sender != address(this) && msg.sender != s_issuer) {
            revert NotIssuerOrItself(msg.sender);
        }
        _;
    }

    constructor(address realEstateToken){
        i_realEstateToken = RealEstateToken(realEstateToken);
    }

    function setIssuer(address _issuer) external onlyOwner {
        s_issuer = _issuer;
        emit SetIssuer(_issuer);
    }

    function assign(uint256 tokenId_, uint256 rentAmount_, uint256 epochDuration_, uint256 programEnd_) external onlyIssuerOrItself {
        if (!i_realEstateToken.exists(tokenId_)) {
            revert TokenIdNotFound();
        }
        uint256 start = block.timestamp;
        paidRent = 0;
        startTime = block.timestamp;
        if (start >= programEnd_) {
            revert InvalidProgramEnd();
        }
        (uint256 oracle, uint256 appraisal) = i_realEstateToken.getEpochPrice(tokenId_, 0);
        paymentDeposited = oracle * i_realEstateToken.totalSupply(tokenId_) * SAFETY_PERCENT / 100;
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

    function payRent(uint256 amount) external planAssigned {
        paidRent += amount;
        emit RentPayment(amount);
    }

    function canLiquidate() public view planAssigned returns (bool) {
        return this.rentDue() > plan.rentAmount;
    }

    function getPlan() external view planAssigned returns (UsagePlan memory) {
        return plan;
    }

    function getPrice() external view planAssigned returns (uint256 tokenPrice) {
        uint256 epochNum = ( block.timestamp - startTime ) / plan.epochDuration;
        (uint256 oracle, uint256 appraisal) = i_realEstateToken.getEpochPrice(tokenId, epochNum);
        return oracle;
    }

    function deposit(uint256 amountPayment) public planAssigned {
        uint256 amountRealEstate = amountPayment / this.getPrice();
        i_realEstateToken.safeTransferFrom(address(this), msg.sender, tokenId, amountRealEstate, "");
        paymentDeposited += amountPayment;
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

    function withdraw(uint256 amountRealEstateToken) public {
        uint256 amountPayment = amountRealEstateToken * this.getPrice();
        if (amountPayment > availableWithdraw()) {
            revert NoFundsToWithdraw();
        }
        i_realEstateToken.safeTransferFrom(msg.sender, address(this), tokenId, amountRealEstateToken, "");
        paymentDeposited -= amountPayment;
    }

}
