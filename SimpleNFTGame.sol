// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "hardhat/console.sol";

error InvalidAmount();
error NotPlayer(address notPlayer);

// Goerli address: 0x24EA3F34cA6218e94d6138EF6C0c073E7BDE1D2f
contract SimpleNFTGame is ERC721URIStorage, Ownable {

    //events
    event OwnerWithdrawFunds(address indexed owner);
    event GameStarted(address indexed player, uint tokenID);
    event AttackFinished(address indexed winner, uint attackerID, uint victimID);
    event NewCharacterCreated(uint indexed newID, address indexed owner);

    //modifiers
    modifier onlyPlayers() {
        if(!players[msg.sender]) {
            revert NotPlayer(msg.sender);
        }
        _;
    }

    struct Character{
        address owner;
        uint numOfAttacksToday;
        uint lastAttackTimestamp;
        uint level;
        uint numOfNewNFTs;
        uint lastNFTtimestamp;
    }

    VRFCoordinatorV2Interface private immutable vRFCoordinatorV2Interface;
    uint public baseFee;
    uint tokenId;
    uint64 subscriptionId;
    mapping(uint => Character) public tokenIDToCharacter;
    mapping(address => bool) private players;

    constructor(VRFCoordinatorV2Interface _vRFCoordinatorV2Interface, uint _baseFee, uint64 _subscriptionId) ERC721("NFTCharacter", "NFT") {
        vRFCoordinatorV2Interface = _vRFCoordinatorV2Interface;
        baseFee = _baseFee;
        subscriptionId = _subscriptionId;
    }

    function startGame() external payable {
        if(msg.value < baseFee) { revert InvalidAmount(); }
        players[msg.sender] = true;
        _safeMint(msg.sender, tokenId);
        //_setTokenURI();
        tokenIDToCharacter[tokenId] = Character(msg.sender, 0, block.timestamp, 1, 0, 0);

        emit GameStarted(msg.sender, tokenId);
        tokenId += 1;
    }

    function requestRandomWords() private returns(uint){
        bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
        uint16 requestConfirmations = 3;
        uint32 callbackGasLimit = 100000;
        uint32 numWords =  2;

        return vRFCoordinatorV2Interface.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function attack(uint attackerID, uint victimID) external onlyPlayers {
        Character memory attacker = tokenIDToCharacter[attackerID];
        require(attacker.owner == msg.sender);
        require(tokenIDToCharacter[victimID].owner != msg.sender);
        require(attacker.numOfAttacksToday < 5);

        if(attacker.lastAttackTimestamp < block.timestamp - 24*60*60) {
            attacker.numOfAttacksToday = 0;
        } 

        attacker.lastAttackTimestamp = block.timestamp;
        attacker.numOfAttacksToday += 1;
        uint winnerID = fight(attackerID, victimID);

        if (winnerID == attackerID){
            tokenIDToCharacter[attackerID].level += 1;
        } else {
            tokenIDToCharacter[victimID].level += 1;            
        }

        emit AttackFinished(tokenIDToCharacter[winnerID].owner, attackerID, victimID);
    }
    //fix ids in args
    function fight(uint id1, uint id2) private returns(uint) {
        uint rand = requestRandomWords();
        uint randMod = rand % 100;
        uint total =  tokenIDToCharacter[id1].level + tokenIDToCharacter[id2].level;
        uint winningID1rate = (100 * tokenIDToCharacter[id1].level) / total;
        
        if(winningID1rate == 50) {
            return ( (rand%2) == 1  ? id1 : id2 );
        }
        return (randMod <= winningID1rate ? id1 : id2);
    }

    function breed(uint characterID) external onlyPlayers {
        Character memory character = tokenIDToCharacter[characterID];
        require(character.owner == msg.sender);
        require(character.numOfNewNFTs <= 5);
        require(character.lastNFTtimestamp < block.timestamp - 24*60*60);
        character.numOfNewNFTs += 1;
        character.lastNFTtimestamp = block.timestamp;
        _safeMint(msg.sender, tokenId);
        //_setTokenURI();
        tokenIDToCharacter[tokenId] = Character(msg.sender, 0, block.timestamp, 1, 0, 0);        

        emit NewCharacterCreated(tokenId, msg.sender);
        tokenId += 1;

    }

    function withdraw() external onlyOwner {
        uint amount = address(this).balance;
        payable(msg.sender).transfer(amount);

        emit OwnerWithdrawFunds(msg.sender);
    }


}
