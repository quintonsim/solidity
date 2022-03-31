//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract Lottery{
    address public manager;
    address payable[] public players;

    constructor(){
        manager = msg.sender;
    }

    receive() external payable{
        require(msg.value == 0.01 ether);
        players.push(payable(msg.sender));
    }

    function getBalance() public view returns(uint){
        require(msg.sender == manager);
        return address(this).balance;
    }

    // Note that this function is not meant for production use and is for testing ONLY
    // Random number generation should be done off-chain or using ChainLink
    function getRandom() public view returns(uint){
        return uint(keccak256(abi.encodePacked(block.difficulty,block.timestamp,players.length)));
    }

    function resetLottery() internal {
        delete players;
    }

    function selectWinner() public{
        require(msg.sender == manager);
        require(players.length >= 3);

        uint num = getRandom();
        uint index = num % players.length;

       address payable winner = players[index];

       winner.transfer(address(this).balance);
       resetLottery();
    }
}
