## LEMs on Blockchains

This repository contains the implementation of a blockchain-based local energy market (LEM) based on the Landau Microgrid Project. It contains a smart contract acting as central market place and automated agents to run simulations.

## Building a private chain

The first step to recreate our implementation of a blockchain-based LEM is to create a private blockchain. Our implementation uses the Ethereum protocol. Further information and extensive guides to build an own private Ethereum blockchain can be found here:

- Go-Ethereum:  https://github.com/ethereum/go-ethereum
- Guide:        https://medium.com/coinmonks/how-to-create-your-own-private-ethereum-blockchain-137ab15989c6

Example Genesis blocks of our implementation using Proof-of-Work and Proof-of-Authority as consensus mechanism can be found in the [chain](https://github.com/koljahe/LEMs-on-Blockchain/tree/master/Chains) folder.

## Deploying Smart Contracts

There are multiple ways to deploy smart contracts on private Ethereum chains. Following this [guide](https://www.virtualforce.io/blockchain/create-deploy-your-first-smart-contract-on-private-blockchain/), you should be able to deploy our contract on your private Ethereum blockchain.

The smart contracts of the market mechanism and the ERC20 token can be found in the [Contracts](https://github.com/koljahe/LEMs-on-Blockchain/tree/master/Contracts) folder. In order to use all functionalities of the market, the smart contracts needs to implement our ERC20 Token. To connect the market to the token, the address of the deployed token smart contract has to be manually inserted into the market smart contract. A comment in the source code marks the variable.
Other than this minor change, the source code of the token and the market mechanism can be copy/pasted and deployed on your private Ethereum chain.

## Interacting
By connecting your private blockchain to a GUI such as [Mist](https://github.com/ethereum/mist) allows you to easily interact with your smart contracts. Functions can be called and Events listened to. Now you can manually insert asks and bids and perform the first market auction.

***Important:*** *Accounts interacting with the market mechanism need to have sufficient amounts of ether and your deployed token. Furthermore, before adding an ask to the market, the appropiate amount of token has to be "allowed" to the market mechanism.*

## Simulation
All automated agents are written in Python. Necessary packages can be easily installed following the [Python's package guide](https://packaging.python.org/tutorials/installing-packages/).

Our simulations pull live-data from the database of the Landau Microgrid Project. We cannot publish its data however, minor changes of the source code allow to include alternative datasets for simulations on the market mechanism.
While consumer.py and producer.py act as automated agents for households of a LEM, server.py is responsible to call the auction mechanism of the smart contract at given points in time. Furthermore, miner.py ensures that blocks are mined reliably before the auction to ensure data flow but empty blocks in between to auction are minimized.
