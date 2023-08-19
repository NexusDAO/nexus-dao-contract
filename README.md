# Nexus System
## Overview
Nexus System is a decentralized autonomous organization (DAO) aggregation platform for the Web3 ecosystem. Any dapp on Aleo can be integrated with the Nexus system, resulting in community ownership and control of the dapp. Each Nexus DAO features an equity-based governance system for coordinating decision-making and modifications, as well as a ledger defining a unique token for each Nexus DAO. During a successful launch, a Nexus proposal is created, distributing governance control to users in decentralized exchanges, collecting initial funds (in exchange for governance control), and transferring control of the dapp to the newly established Nexus DAO.

## Our Features
### User registration and login
Log in to the platform using the Leo wallet
### User profile
Allows users to edit and manage their profile (saved to NFT):
Set username
Upload and change profile picture
Fill in the personal introduction
Shows user participation and contribution:
Number of votes
Number of proposals
### DAO creation and management
Conditions for creating a DAO organization:
Raise funds ≥m
Community members ≥n
Issue governance tokens
Allows users to create new DAO organizations, including input:
Organization Name
Organization description
Organization icon
Organization type 
Official link
How users can join the DAO organization:
Hold and pledge the governance tokens issued by the organization on the platform
### Proposal management
Allows DAO organization members to create and submit proposals, including input:
Conditions:
Need to pledge tokens
Return tokens when the proposal passes
Penalty if the proposal fails
Proposal title
Proposal type
Proposal summary
Proposal body
Proposal start and end time (in days, with a minimum duration of one day)
Proposal ending:
Normal proposal ending:
Proposal expires
The proposal vote result reached
### Governance mechanism
Voting Conditions:
Hold governance tokens of the organization
Stake governance tokens of the organization
Voting Weights:
Weighted by token staking amount
Weighted by token staking duration
Weighted by the number of votes cast
Voting Rules:
Each account can vote multiple times on the same proposal
Non-staked tokens:
Cannot be used for voting
Staked tokens:
Conditions: The staking period must fully contain the voting period
Can be used in any amount
Can vote multiple times
Tokens that have been used for voting cannot be selected again
Voting Results Determination:
When the number of voters is greater than or equal to 3% of the total number of members in the organization: The voting result is adopted
When the number of voters is less than 3% of the total number of members in the organization: The proposal is rejected
Voting Page Display:
Voting rules
Voting mechanism
Proposal content
Display after voting ends (to allow members to evaluate the impact of the decision):
Voting results
Participation status:
Number of votes
Pass rate
Dashboard
Overview Chart:
Total number of organizations
The total amount of funds
Total number of members
Total number of recently active members
Total number of proposals
Total number of recently proposed projects
Total percentage of recently adopted proposals
Total number of governance token holders
Total number of governance token stakes
Data Table:
Search:
Organization Name
Filter:
Organization type
Fields:
Fund ranking
Organization Name
Total funds
Token count
Token price
Token name
Token holder count
Token staker count
Proposal count
Vote count
Proposal pass rate

## Build Guide

To compile this Aleo program, run:
```bash
aleo build
```
## How to Deploy
`https://medium.com/@CroutonDigital/aleo-how-to-deploy-a-smart-contract-d7f437cebea7`
