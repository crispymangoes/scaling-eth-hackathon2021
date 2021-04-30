// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import {Pool} from "./Pool.sol";

struct userVerification{
        bytes32 requestId;
        bool verified;
        string twitterHandle;
    }

contract PoolFactory is Ownable{
    bool allowPoolCreation;
    address[] poolList;
    address TWITTER_VERIFY_ADDRESS;
    iTwitterVerify twitterVerify;
    modifier okayToCreatePool(){
        require(allowPoolCreation, "Pool creation is currently not allowed!");
        _;
    }
    
    constructor(address _twitterVerifyAddress){
        TWITTER_VERIFY_ADDRESS = _twitterVerifyAddress;
        twitterVerify = iTwitterVerify(TWITTER_VERIFY_ADDRESS);
    }
    
    
    function setTwitterVerifyAddress(address _address) external onlyOwner{
        TWITTER_VERIFY_ADDRESS = _address;
        twitterVerify = iTwitterVerify(TWITTER_VERIFY_ADDRESS);
    }
    function changePoolCreationBool( bool _bool) external onlyOwner{
        allowPoolCreation = _bool;
    }
    
    function createPool(
    string memory _poolName, 
    uint _capital, 
    address _capitalAddress, 
    address _nftAddress, 
    address _rng, 
    uint _campaignLength, 
    uint _votingLength, 
    uint _decisionLength, 
    uint _submissionLength)
    external {
        userVerification memory userData = twitterVerify.getVerification(msg.sender);
        require(userData.verified, "Caller address is not verified with Twitter!");
        Pool pool = new Pool(_poolName, userData.twitterHandle, _capital, _capitalAddress, _nftAddress, msg.sender, _rng, _campaignLength, _votingLength, _decisionLength, _submissionLength);
        poolList.push(address(pool));
    }
}

interface iTwitterVerify{

    function getVerification(address _user) external returns(userVerification memory); //TODO why does this need memory?
}
