// This example code is designed to quickly deploy an example contract using Remix.

pragma solidity 0.6.6;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/VRFConsumerBase.sol";

contract RandomNumberConsumer is VRFConsumerBase {
    
    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public randomResult;
    address[] whitelist;
    uint whitelistCount;
    address public owner;
    
    modifier isWhitelist() {
        bool pass = false;
        for (uint i=0; i<whitelistCount; i++){
            if (msg.sender == whitelist[i]){
                pass = true;
                break;
            }
        }
        require(pass, "Message sender not found in whitelist!");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function!");
        _;
    }
    
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Mumbai
     * Chainlink VRF Coordinator address: 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
     * LINK token address:                0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Key Hash: 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
     */
    constructor() 
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        ) public
    {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        owner = msg.sender;
    }
    
    /** 
     * Requests randomness from a user-provided seed
     ************************************************************************************
     *                                    STOP!                                         * 
     *         THIS FUNCTION WILL FAIL IF THIS CONTRACT DOES NOT OWN LINK               *
     *         ----------------------------------------------------------               *
     *         Learn how to obtain testnet LINK and fund this contract:                 *
     *         ------- https://docs.chain.link/docs/acquire-link --------               *
     *         ---- https://docs.chain.link/docs/fund-your-contract -----               *
     *                                                                                  *
     ************************************************************************************/
    function getRandomNumber(uint256 userProvidedSeed) public isWhitelist returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee, userProvidedSeed);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }
    
    function seeRandomNumber() external returns(uint) {
        return randomResult;
    }
    
    /**
     * Withdraw LINK from this contract
     * 
     */
    function withdrawLink(address _address) external onlyOwner {
        require(LINK.transfer(_address, LINK.balanceOf(address(this))), "Unable to transfer");
    }
    
    function addToWhitelist(address _address) external onlyOwner{
        whitelist.push(_address);
        whitelistCount++;
    }
    
    function transferOwnership(address _address) external  onlyOwner {
        owner = _address;
    }
    
}
