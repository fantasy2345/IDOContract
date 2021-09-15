// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721Pausable.sol";
import "./interfaces/IDecentralizedAI.sol";
import "./curves/Exponential.sol";


contract IDO is Ownable, Exponential {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant MAX_TOKEN_COUNT = 10000000000;
    uint256 public constant MAX_PER_TRANSACTION = 1000000;
    uint256 public constant totalSoldCount = 0;
    uint256 public constant lockTime = 256;
    uint256 public constant lockSoldCount = 5000000000;
    uint256 public constant lockPastTime = 100000;
    uint256 public IDOIssue;
    
    
    struct IDORecord {
        uint256 issue;
        IBEP20 idoToken;
        IBEP20 receiveToken;
        //decimals 18
        uint256 price;
        //IDO总量
        uint256 idoTotal;
        //开始时间
        uint256 startTime;
        //时长
        uint256 duration;
        uint256 maxLimit;
        uint256 chargeTime;
        //接收的总量
        uint256 receivedTotal;
        mapping(address => uint256) payAmount;
        mapping(address => bool) isWithdraw;
        mapping(address => uint256) payLastTime;
    }

    mapping(uint256 => IDORecord) public IDODB;

    IDecentralizedAI public DEAI;
    address public constant funderAddress = 0x6F84Fa72Ca4554E0eEFcB9032e5A4F1FB41b726C;
    address public constant corporateAddress = 0xcBCc84766F2950CF867f42D766c43fB2D2Ba3256;
    string public baseTokenURI;

    event IDOCreate(
        uint256 issue,
        address idoToken,
        address receiveToken,
        uint256 Maxprice,
        uint256 maxLimit,
        uint256 idoTotal,
        uint256 startTime,
        uint256 duration
    );
    constructor( IDecentralizedAI _deai) {
        DEAI = _deai;
        IDOIssue = 0;
        pause(true);                    //pause meaning
    }

    modifier saleIsOpen(address _buyer) {
        require(now - lastBoughtTime[_buyer] >= lockTime, "You have to wait to buy token");
        require( totalSoldCount >= lockSoldCount, "Not enough tokens left");
        require( now - deployTime >= lockPastTime,"Sales is locked!");

        ///Price is readhed check!!!!
        _;
    }

    modifier sellIsOpen(address _seller) {
        if( _seller == corporateAddress ) _;
        if( finishedIDO == 1 ) _;
    }


    function createIDO(
        IDecentralizedAI idoToken,
        IDecentralizedAI receiveToken,
        uint256 Maxprice,
        uint256 idoTotal,
        uint256 maxLimit,
        uint256 chargeTime,
        uint256 startTime,
        uint256 duration
    ) external onlyOwner {
        require( block.timestamp >
            IDOOB[IDOIssue].startTime.add( IDOOB[IDOIssue].duration),
            "ido is not over yet");
        require( address(idoToken) != address(0),
            "idoToken address cannot be 0");
        require( address(receiveToken) != address(0),
            "receiveToken address cannot be 0");
        IDOIssue = IDOIssue.add(1);
        IDORecord storage ido = IDOOB[IDOIssue];
        ido.issue = IDOIssue;
        ido.idoToken = idoToken;
        ido.receiveToken = receiveToken;
        ido.Maxprice = Maxprice;
        ido.maxLimit = maxLimit;
        ido.chargeTime = chargeTime;
        ido.idoTotal = idoTotal;
        ido.startTime = startTime;
        ido.duration = duration;

        idoToken.safeTransferFrom( msg.sender, address(this), idoTotal);
        emit IDOCreate(
            IDOIssue,
            address(idoToken),
            address(receiveToken),
            price,
            maxLimit,
            idoTotal,
            startTime,
            duration
        );
    }

    function stack( uint256 amount) external saleIsOpen(msg.sender) {
        require(msg.sender != address(0), "address is 0");
        require( IDOIssue > 0, "IDO that does not exist");

        
        //require( totalSoldCount >= lockSoldCount, "Not enough tokens left");
        

        IDORecord storage record = IDOOB[IDOIssue];
        require( block.timestamp > record.startTime &&
                 block.timestamp < record.startTime + record.duration,
                 "IDO is not in progress.");
        
        require( block.timestamp - record.payLastTime[msg.sender] > record.chargeTime,
                 "wait until time reached");
        
        require( record.payAmount[msg.sender] + value <= MAX_PER_TRANSACTION,
                 "amount cannot bigger than 1000000");
        record.payLastTime[msg.sender] = block.timestamp;

        record.payAmount[msg.sender] += amount;
        record.receivedTotal += amount;
        record.receiveToken.safeTransferFrom( msg.sender, address(this), amount);

        emit Stacked(IDOIssue, msg.sender , value);
        

        //corporate wallet will sell in uniswap
    }

    function transfer( uint256 amount ) external {
        require(msg.sender != address(0), "address is 0");
        require( IDOIssue > 0, "IDO that does not exist");

        
        //require( totalSoldCount >= lockSoldCount, "Not enough tokens left");
        

        IDORecord storage record = IDOOB[IDOIssue];
        require( block.timestamp > record.startTime &&
                 block.timestamp < record.startTime + record.duration,
                 "IDO is not in progress.");
        
        require( block.timestamp - record.payLastTime[msg.sender] > record.chargeTime,
                 "wait until time reached");
        
        require( record.payAmount[msg.sender] + value <= MAX_PER_TRANSACTION,
                 "amount cannot bigger than 1000000");

        require( record.maxPrice < getPrice(),
                 "Max price reached");

        record.idoToken.safeTransferFrom( address(this), msg.sender, amount);

        // sell 91.9% to uniswap
        record.idoToken.safeTransferFrom( address(this), uniswapAddr, amount * 0.919);
    }

    function sell(address recipient, uint256 amount) external {
        require(msg.sender != address(0), "address is 0");
        require(recipient != address(0), "recipient address is 0");
        require( IDOIssue > 0, "IDO that does not exist");

        IDORecord storage record = IDOOB[IDOIssue];
                require( block.timestamp > record.startTime &&
                 block.timestamp < record.startTime + record.duration,
                 "IDO is not in progress.");

        if( block.timestamp > record.startTime &&
            block.timestamp < record.startTime + record.duration ) {
            require( msg.sender == corporateAddress, "Only corporate Address is allowed during IDO!");
        }
        require( block.timestamp > record.startTime, "Is not sell time");
        require( msg.sender == corporateAddress || block.timestamp > record.startTime + record.duration,
                 "Not finished IDO" );

        uint256 finishedIDOTime = record.startTime + record.duration;
        if( block.timestamp - finishedIDOTime <= 60 days ) {
            int tAmount = DEAI.balanceOf(msg.sender);
            int rAmount = tAmount / 20;
            require( rAmount >= amount, "Cannot sell more than 20%");
            DEAI.transferFrom(msg.sender, recipient, amount);
        } else if( timestamp - finishedIDOTime <= 120 days ) {
            int tAmount = DEAI.balanceOf(msg.sender);
            int rAmount = tAmount / 50;
            require( rAmount >= amount, "Cannot sell more than 50%");           
            DEAI.transferFrom(msg.sender, recipient, amount);
        } else {
            int rAmount = DEAI.balanceOf(msg.sender);
            require( rAmount >= amount, "Cannot sell your amount");
            DEAI.transferFrom(msg.sender, recipient, amount);
        }
    }


    function totalSupply() external view returns(uint256) {
        return IDODB[IDOIssue].receivedTotal;
    }
    function userPayValue( uint256 issue, address account) public view returns(uint256) {
        return IDODB[issue].payAmount[account];
    }

    function getPrice(  ) public view returns( uint256 ) {
        return calculatePrice();
    }

    function withdraw(uint256 issue) external {
        require( issue <= IDOIssue && issue > 0, "IDO that does not exist.");

        IDORecord storage record = IDODB[issue];

        require( block.timestamp > IDODB[issue].startTime + record.duration,
                 "ido is not over yet");

        require( !record.isWithdraw[msg.sender], "Cannot claim repeatedly.");

        uint256 idoAmount;
        uint256 sendBack;

        record.isWithdraw[msg.sender] = true;
        (idoAmount, sendBack) = available( msg.sender , issue);
        record.idoToken.safeTransfer( msg.sender, idoAmount);
        if( sendBack > 0 ) {
            record.receiveToken.safeTransfer(msg.sender, sendBack);
        }

        emit Withdraw( issue, msg.sender, idoAmount, sendBack);
    }

    function isWithdraw( uint256 issue, address account) public view returns(bool){
        return IDODB[issue].isWithdraw[account];
    }
}