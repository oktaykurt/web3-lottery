// SPDX-License-Identifier: MIT
pragma solidity >=0.7.1 <0.9.0;

import "node_modules/@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "node_modules/@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Errors
error Raffle_NotEnoughETHEntered();
error Raffle__RaffleNotOpen();
error Raffle__TransferFailed();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

contract Raffle is VRFConsumerBaseV2 {
    enum RaffleState {
        OPEN, // = 0
        CALCULATING // = 1
    }

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoorinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    address private s_recentWinner;
    address payable[] private s_players;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;

    // Events
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);


    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        bytes32 gasLane,
        uint256 interval

    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoorinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
        
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) revert Raffle_NotEnoughETHEntered();
    }

        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }


        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);

    function checkUpkeep(
        bytes memory /* checkData */
    )
    public view override returns(bool unkeepNeeded, bytes memory  /* performData */) {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (isOpen && timePassed && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
            
    }



    function performUpkeep(bytes calldata /* performaData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState),
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoorinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, //_requestId
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance("")};

        if(!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(recentWinner);
    }
}
