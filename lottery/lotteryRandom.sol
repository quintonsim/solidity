//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is VRFConsumerBaseV2{
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    // Rinkeby testnet config
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    address link_token_contract = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  1;

    address public owner;
    address payable[] public players;
    uint256 randomIndex;
    uint256 public requestId;
    uint64 public s_subscriptionId;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link_token_contract);
        owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    receive() external payable{
        require(msg.value == 0.01 ether);
        players.push(payable(msg.sender));
    }

    function getBalance() public view returns(uint){
        require(msg.sender == owner);
        return address(this).balance;
    }

    function getIndex() public view returns(uint){
        require(msg.sender == owner);
        return randomIndex;
    }

    function requestRandomWords() external {
        require(msg.sender == owner);
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomNums
    ) internal override {
        randomIndex = (randomNums[0] % players.length) + 1;
    }

    function resetLottery() internal {
        delete players;
    }

    function selectWinner() public{
        require(msg.sender == owner);
        require(players.length >= 3);

       address payable winner = players[randomIndex];

       winner.transfer(address(this).balance);
       resetLottery();
    }
}
