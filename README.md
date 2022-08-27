# smart-contracts
Few basic smart contracts

# SimpleNFTGame

SimpleNFTGame allows users to get NFT and use it to attack other players. 
When the player attacks, a random number is generated using Chainlink, it is reduced to a maximum of 100. 
The percentage of the chance of victory for the attacker is calculated. 
It is checked whether that random number is in the range of the attacker, if so, he has won, if not, then opponent is winner. 
The winner is rewarded by having their NFT level up. It can be attacked a maximum of 5 times per day. 
Players can also generate new NFTs, up to a maximum of 5 times.
