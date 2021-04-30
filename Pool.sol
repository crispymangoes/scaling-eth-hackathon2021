// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
//TODO tie breaker logic not implemented
contract Pool {
    
    address poolOwner;
    IERC20 private token; //The input token for the pool campaign usually CRTV
    IERC721 private nft;
    iRandomNumberGenerator private rng;
    string public poolName; //Brand can call the pool whatever they want IE "Campaing to design the next Coca Cola Bear"
    string public brandName; //Pulled from Twitter handle is not changeable
    uint public funds; //Capital Pool owner deposits to start pool!
    uint public submissionEndBlock;
    uint public fanVotingEndBlock;
    uint public brandVotingEndBlock;
    uint public campaignEndBlock;
    bool public topTenFound;
    uint[10] public topTen;
    uint[10] public topTenAmount;
    uint winningSubmission; // Index of the winning submission
    uint userDeposit; //
    bool winnerSelected;
    
    struct User{
        address user;
        uint amount;
    }
    
    struct submission {
        uint[] nftList;
        mapping(address => uint) userIndex;
        User[] users; //should I make fan zero be the artist? then I can keep their address and 
        uint userCount;
        uint totalVote;
    }
    
    mapping(uint => submission) submissions;
    uint submissionCount = 0;
    
    modifier onlyPoolOwner(){
        require (msg.sender == poolOwner, "Only the Pool Owner can call this function!");
        _;
    }
    
    modifier onlyFans() {
        require(msg.sender != poolOwner, "Only Fans can call this function!");
        _;
    }
    
    
    constructor(string memory _poolName, string memory _brandName, uint _capital, address _capitalAddress, address _nftAddress, address _poolOwner, address _rng, uint _campaignLength, uint _votingLength, uint _decisionLength, uint _submissionLength) {
        poolOwner = _poolOwner;
        funds = _capital;
        token = IERC20(_capitalAddress);
        require(token.transferFrom(poolOwner, address(this), funds), "trandferFrom failed, pool not backed by funds!");
        
        userDeposit = funds / 10;
        nft = IERC721(_nftAddress);
        rng = iRandomNumberGenerator(_rng);
        
        poolName = _poolName;
        brandName = _brandName;
        uint currentBlock = block.number;
        submissionEndBlock = currentBlock + _submissionLength;
        fanVotingEndBlock = submissionEndBlock + _votingLength;
        brandVotingEndBlock = fanVotingEndBlock + _decisionLength; 
        campaignEndBlock = currentBlock + _campaignLength;
    }
    
    function changeName(string memory _name) external onlyPoolOwner {
        poolName = _name;
    }
    
    function createSubmission( uint[3] memory nfts) external {
        require(block.number < submissionEndBlock, "Can not add submissions during the fan voting period");
        require(token.transferFrom(msg.sender, address(this), userDeposit), "trandferFrom failed, submission not backed by funds!");
        for(uint i=0; i < 3; i++){
            nft.transferFrom(msg.sender, address(this), nfts[i]);//Transfer them to the contract Think we need to do a require, we could require the nft owner is the conrtact?
            submissions[submissionCount]. nftList.push(nfts[i]);
        }
        User memory artist = User(
            {
                user: msg.sender,
                amount: userDeposit
            });
        submissions[submissionCount].userIndex[msg.sender] = 0; //Set artist as the 0 index
        submissions[submissionCount].userCount++;
        submissions[submissionCount].users.push(artist);
        submissionCount++;
    }
    
    function fanVote(uint _submissionNumber) external onlyFans {
        //TODO I think its okay to read the zero address of an empty array, I am assuming it returns zero but I need to verify this!
        require( msg.sender != submissions[_submissionNumber].users[0].user, "Artist can not vote for their own submission!");
        require(block.number >= submissionEndBlock, "Can not start voting until submission period is over!");
        require(block.number <= brandVotingEndBlock, "Fan Voting Period is Over!");
        require(submissions[_submissionNumber].nftList[0] > 0, "There are no NFTs in this submission!");
        require(token.transferFrom(msg.sender, address(this), userDeposit), "trandferFrom failed, vote not backed by funds!");
        
        //Check if the user is already in the submission and thorw an error if they are!
        for (uint i=1; i< submissions[_submissionNumber].userCount; i++){
            if ( msg.sender == submissions[_submissionNumber].users[i].user){
                require(false, "User has already voted for this submission!");
            }
        }
        // If user isn't in the submission, then add them!
        User memory fan = User(
            {
                user: msg.sender,
                amount: userDeposit
            });
        submissions[_submissionNumber].users.push(fan);
        submissions[_submissionNumber].userCount++;
        
    }
    
    
    function getTopTen() external onlyPoolOwner{
        require(!topTenFound, "Top Ten Already Calcuated!");
        require(block.number > fanVotingEndBlock, "Cannot select top ten until fan voting is over!");
        //Function goes through all the submissions
        uint smallStake; //The submission with the smallest amount in the top ten. This is that small amount
        uint indexSmall; //The index of the submission with the smallest amount in the top ten
        uint submissionSum; // Used to add up the total vote count for a submission
        bool spotFound; //Bool used to determine if the smallest top ten submission needs to be compared to the current submission vote sum
        for (uint i=0; i<submissionCount; i++){
            submissionSum = 0;
            spotFound = false;
            for ( uint j=1; j < submissions[i].userCount; j++){
                submissionSum = submissionSum + submissions[i].users[j].amount;
            }
            smallStake = topTenAmount[0];
            indexSmall = 0;
            for ( uint k=0; k < 10; k++){
                if (topTenAmount[k] == 0){
                    topTenAmount[k] = submissionSum;
                    topTen[k] = i;
                    spotFound = true;
                    break;
                }
                //Find the smallest amount in the top ten
                if (topTenAmount[k] < smallStake){
                    smallStake = topTenAmount[k];
                    indexSmall = k;
                }
            }
            //If a spot isn't found then check and see if the submission amount is greaater than the smallest top ten amount
            if(!spotFound){
                if (submissionSum > smallStake){
                    //If it is then write over the small submission with the current submission
                    topTenAmount[indexSmall] = submissionSum;
                    topTen[indexSmall] = i;
                }
            }
            submissions[i].totalVote = submissionSum;
        }
        //TODO in order to handle tie breakers, scan through the top ten and find the smallest value. If you find the smallest value multiple times, record how many times that happens.
        // Then that number is how many spots in the top ten are up for grabs in a tiebreaker.
        // Now scan through all the submissions again and count how many submissions have the same total vote(total vote being equal to smallest value in the top ten)
        // If this number is the same as the number you found when searching in the top ten you are gucci, if it isn't then a tie breaker voting period needs to start.
        rng.getRandomNumber(block.number);
        topTenFound = true;
        
    }
    
    function selectWinner(uint submissionIndex) external onlyPoolOwner{
        require(!winnerSelected, "Already selected winner!");
        require(block.number > campaignEndBlock, "Can only choose a winner after the campaign is over!");
        require(topTenFound, "You have to call getTopTen first!");
        winnerSelected = true;
        bool winnerInTopTen;
        for (uint i=0; i<10; i++){
            if (submissionIndex == topTen[i]){
                winnerInTopTen = true;
                break;
            }
        }
        require(winnerInTopTen, "You must select a winner from the top ten list!");
        winningSubmission = submissionIndex;
        //distribute awards
        nft.transferFrom(address(this), submissions[winningSubmission].users[0].user, submissions[winningSubmission].nftList[0]);
        uint winnerIndex = (rng.seeRandomNumber() % (submissions[submissionIndex].userCount-1)) + 1;
        address luckyFan = submissions[submissionIndex].users[winnerIndex].user;
        nft.transferFrom(address(this), luckyFan, submissions[winningSubmission].nftList[1]);
        nft.transferFrom(address(this), poolOwner, submissions[winningSubmission].nftList[2]);
        token.transferFrom(address(this), poolOwner, funds);
    }
    
    function cashout(uint _submissionNumber) external {
        require(block.number > campaignEndBlock, "Can not cashout until campaign is over!");
        bool userFound;
        uint index;
        for (uint i=0; i<submissions[_submissionNumber].userCount; i++){
            if (submissions[_submissionNumber].users[i].user == msg.sender){
                userFound = true;
                index = i;
                break;
            }
        }
        uint tmpBal = submissions[_submissionNumber].users[index].amount;
        submissions[_submissionNumber].users[index].amount = 0;
        if (userFound && index == 0){
            //This is an artist that needs to withdraw funds and NFTS
            //Send back their NFTs if they arent the winner, and their funds. If they are the winner then jsut send back the funds
            require(token.transferFrom(address(this), msg.sender, tmpBal));
            if (_submissionNumber != winningSubmission){
                for(uint i=0; i < 3; i++){
                    nft.transferFrom(address(this), msg.sender,  submissions[_submissionNumber].nftList[i]);//Transfer them to the contract Think we need to do a require, we could require the nft owner is the conrtact?
                }
                submissions[_submissionNumber].nftList = [0,0,0];//Set the nftList equal to a list of zeroes 
            }
        }
        
        else if (userFound){
            //This is a fan that just needs their tokens back
            require(token.transferFrom(address(this), msg.sender, tmpBal));
        }
        else {
            require(false, "User was not found in submission!");
        }
    }
    
}

interface iRandomNumberGenerator {
    function getRandomNumber(uint256 userProvidedSeed) external returns (bytes32 requestId);
    function seeRandomNumber() external returns(uint);
}

