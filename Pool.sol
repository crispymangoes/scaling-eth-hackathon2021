// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
contract Pool {
    
    //TODO Chainlink VRF
    
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
    bool public topTenFound = false;
    
    struct User{
        address user;
        uint amount;
    }
    
    struct submission {
        uint[] nftList;
        mapping(address => uint) userIndex;
        User[] users; //should I make fan zero be the artist? then I can keep their address and 
        uint userCount;
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
    
    function createSubmission(uint collateral) external {
        require(block.number < submissionEndBlock, "Can not add submissions during the fan voting period");
        //require collateral is >= 10% of brand deposited funds
        //require colalteral transfers to contract
        User memory artist = User(
            {
                user: msg.sender,
                amount: collateral
            });
        submissions[submissionCount].userIndex[msg.sender] = 0; //Set artist as the 0 index
        submissions[submissionCount].userCount++;
        submissions[submissionCount].users.push(artist);
        submissionCount++;
    }
    
    //TODO I'm not sure the best way to do this
    function bulkAddNFTtoSubmission(uint submissionIndex) external {
        require(block.number < submissionEndBlock, "Can not add NFTs during the fan voting period");
        require(msg.sender == submissions[submissionIndex].users[0].user, "Cannot add NFTs to a submission you did not create!");
    }
    
    function addNFTtoSubmission(uint submissionIndex, uint _tokenId) external{
        require(block.number < submissionEndBlock, "Can not add NFTs during the fan voting period");
        require(msg.sender == submissions[submissionIndex].users[0].user, "Cannot add NFTs to a submission you did not create!");
        nft.transferFrom(msg.sender, address(this), _tokenId); //Transfer the NFT to the pool
        submissions[submissionIndex].nftList.push(_tokenId); //Add the NFT to the list of NFTs
    }
    
    //TODO this allows artists to vote on their own submission
    function fanVote(uint _submissionNumber, uint _amount) external onlyFans {
        //TODO I think its okay to read the zero address of an empty array, I am assuming it returns zero but I need to verify this!
        require(block.number >= submissionEndBlock, "Can not start voting until submission period is over!");
        require(block.number <= brandVotingEndBlock, "Fan Voting Period is Over!");
        require(submissions[_submissionNumber].nftList[0] > 0, "There are no NFTs in this submission!");
        require(token.transferFrom(msg.sender, address(this), _amount), "trandferFrom failed, vote not backed by funds!");
        
        //Check if the user is already in the submission!
        bool alreadyVoted = false;
        for (uint i=0; i< submissions[_submissionNumber].userCount; i++){
            if ( msg.sender == submissions[_submissionNumber].users[i].user){
                alreadyVoted = true;
                submissions[_submissionNumber].users[i].amount = submissions[_submissionNumber].users[i].amount + _amount; //Add to the users old amount
                break;
            }
        }
        // If user isn't in the submission, then add them!
        if (!alreadyVoted){
            User memory fan = User(
                {
                    user: msg.sender,
                    amount: _amount
                });
            submissions[_submissionNumber].users.push(fan);
            submissions[_submissionNumber].userCount++;
        }
    }
    
    
    function getTopTen() external onlyPoolOwner{
        require(!topTenFound, "Top Ten Already Calcuated!");
        require(block.number > fanVotingEndBlock, "Cannot select top ten until fan voting is over!");
        //Function goes through all the submissions
        rng.getRandomNumber(block.number);
        topTenFound = true;
    }
    
    function selectWinner(uint submissionIndex) external onlyPoolOwner{
        require(block.number > campaignEndBlock, "Can only choose a winner after the campaign is over!");
        require(topTenFound, "You have to call getTopTen first!");
        //distribute awards
    }
    
    function cashout(uint _submissionNumber) external {
        require(block.number > campaignEndBlock, "Can not cashout until campaign is over!");
        //If they are a fan, then just return ERC20 tokens.
        //If they are the artist then return the ERC20s and the ERC721s
    }
    
}

interface iRandomNumberGenerator {
    function getRandomNumber(uint256 userProvidedSeed) external returns (bytes32 requestId);
    function seeRandomNumber() external returns(uint);
}
