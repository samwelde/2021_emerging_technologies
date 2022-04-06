                                                            /** 
                                                             * 
                                                             * Springsemester 2021
                                                             * emerging technologies 
                                                             * university of fribourg
                                                             * 
                                                             * */

pragma solidity 0.6.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/VRFConsumerBase.sol";

contract ChainlinkRoulette is VRFConsumerBase {
    
    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public randomResult;
    uint256 public maxBet = 1 ether;                        // set default value, max, to prevent unable to pay winner
    uint256 public maxBetRatio = 1000;                      // dynamic maxbet ratio so casino can rewin big losses
    
    address payable public casino;                          // public address = transparent for public to trust where they can pay to
    
    struct Bet {                                            // will include following data / lets choose the structure 
        address payable addr;
        uint bet_num;
        uint amount;
    }
    
                                                            // have a library for all different kind of bets / create a mapping
    mapping(bytes32 => Bet) public book;                    // value is associated with every bytes32 key bet
    
    
                                                            // define variable
    uint256 public spinResult;
    
    constructor() 
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9,     // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088      // LINK Token
        ) public
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18;                               // 0.1 LINK
        casino = msg.sender;                                // we add ability to controll/ edit function (everyone can, caller = casino)
    }
    
                                                            /*
                                                             * Requests randomness from a user-provided seed
                                                             * STOP!                                     
                                                             * THIS FUNCTION WILL FAIL IF THIS CONTRACT DOES NOT OWN LINK               
                                                             *                        
                                                             * Learn how to obtain testnet LINK and fund this contract:                 
                                                             * https://docs.chain.link/docs/acquire-link               
                                                             * https://docs.chain.link/docs/fund-your-contract              
                                                             */
    
    modifier checkMaxBet{                                   // is setting bet limit and exceeding situation
        require(msg.value <= maxBet, "This bet exceed max possible bet");
        _;
    }

                                                            // user needs seeds / can bet on nr. / needs to pay / fct needs to controll maxBet limit
    function spinWheel(uint256 userProvidedSeed, uint256 bet_num) payable public checkMaxBet {  //bet_num is 0-36
        
        address payable bettor = msg.sender;                // we define the player as bettor as casino
        
                                                            // get random number for spinWheel
        bytes32 current_request_id = getRandomNumber(userProvidedSeed); // id to have user specific settings
        
                                                            // store request id and address with the key [current_request_id]
        Bet memory cur_bet = Bet(bettor, bet_num, msg.value);
        book[current_request_id] = cur_bet;
    }

    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

                                                            /*
                                                             * Callback function used by VRF Coordinator
                                                             */
     
     function addBalance() external payable {               // deposit money/ amount of wei
        maxBet = address(this).balance / maxBetRatio;
     }
     
     function withdrawWei(uint withdraw_wei_amount) public { // withdraw money/ amount of wei
         casino.transfer(withdraw_wei_amount);
         maxBet = address(this).balance / maxBetRatio;
    }
     
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
        
                                                            // load bet from betbook/ memory, to put bet in the request 
        Bet memory _curBet = book[requestId];               // load bet from memory out of book
        uint _betNum = _curBet.bet_num;
        address payable _bettor = _curBet.addr;
        uint _amount = _curBet.amount;
        
                                                            // transform randomResult uint256 to real number = calculate spin Result
        uint _spinResult = randomResult % 36; // modulo 36
        
                                                            // display spin result to public (only works if low volume)
        spinResult = _spinResult;                           // define variable outside and before 
        
                                                            // pay if there are a winner
        if (_spinResult == _betNum) {
            (bool sent, bytes memory data) = _bettor.call.value(_amount*35)("");
            require (sent, "failed to send ether :(");
        }
        maxBet = address(this).balance /maxBetRatio;        // adapt maxBet if bank loses, so rewin is possible
        delete book[requestId];
    }
    
                                                            /**
                                                             * Withdraw LINK from this contract
                                                             * DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
                                                             * THIS IS PURELY FOR EXAMPLE PURPOSES.
                                                             */
    function withdrawLink() external {
        require(LINK.transfer(msg.sender, LINK.balanceOf(address(this))), "Unable to transfer");
    }
}