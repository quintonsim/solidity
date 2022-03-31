//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract AuctionCreator{
    Auction[] public auctions;

    function createAuction() public{
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}

contract Auction{
    address payable public owner;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;

    enum State {Started, Running, Ended, Canceled}
    State public auctionState;

    uint public highestBindingBid;
    address payable public highestBidder;
    uint bidIncrement;
    mapping(address => uint) public bids;

    bool internal locked;

    constructor(address eoa){
        owner = payable(eoa);
        auctionState = State.Running;

        // We use block numbers to calculate time as block.timestamp can be manipulated by miners
        startBlock = block.number;
        endBlock = block.number + 5; //40320
        ipfsHash = '';
        bidIncrement = 500000000000000000;// 0.5 ETH
    }

    //Modifier used to mitigate reentry attacks
    modifier noReentry() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner{
        require(owner == msg.sender);
        _;
    }

    modifier notOwner{
        require(owner != msg.sender);
        _;
    }

    modifier withinTime{
        require(block.number >= startBlock);
        require(block.number <= endBlock);
        _;
    }

    modifier auctionEnded{
        require(block.number > endBlock || auctionState == State.Ended || auctionState == State.Canceled);
        _;
    }

    function min(uint a, uint b) pure internal returns(uint){
        if(a < b){
            return a;
        } else{
            return b;
        }
    }

    function placeBids() public payable notOwner withinTime {
        require(auctionState == State.Running);
        require(msg.value >= 1000000000000000000);//1 ETH

        uint currentBid = bids[msg.sender] + msg.value;

        //Current bid must be higher than highest bid + 100 wei
        require(currentBid >= bids[highestBidder] + 1000000000000000000);//1 ETH

        bids[msg.sender] = currentBid;

        highestBindingBid = bids[highestBidder] + bidIncrement;
        highestBidder = payable(msg.sender);
    }

    function cancelAuction() public onlyOwner {
        auctionState = State.Canceled;
    }

    function finalizeAuction() public noReentry {
        require(auctionState == State.Canceled || block.number > endBlock);
        require(msg.sender == owner || bids[msg.sender] > 0);

        address payable recipient;
        uint amount;

        // Withdrawl Pattern. Used to mitigate Reentrancy Attacks
        if(auctionState == State.Canceled){// Bidders can withdraw funds upon cancelation
            recipient = payable(msg.sender);
            amount = bids[msg.sender];
        } else{// Owner can transfer out highestBindingBid
            if(msg.sender == owner){
                recipient = owner;
                amount = highestBindingBid;
            } else {// highestBidder only pays for highestBindingBid. Gets refund of excess.
                if(msg.sender == highestBidder){
                    recipient = highestBidder;
                    amount = bids[highestBidder] - highestBindingBid;
                } else{// All other bidders can withdraw funds after auction ends
                    recipient = payable(msg.sender);
                    amount = bids[msg.sender];
                }
            }
        }

        bids[recipient] = 0;
        recipient.transfer(amount);
    }
}
