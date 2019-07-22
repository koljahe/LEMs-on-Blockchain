## LEMs on Blockchains

This repository contains the implementation of a blockchain-based local energy market (LEM) based on the Landau Microgrid Project. It contains a smart contract acting as central market place and automated agents to run simulations.

## Building a private chain

The first step to recreate our implementation of a blockchain-based LEM is to create a private blockchain. Our implementation uses the Ethereum protocol. Further information and extensive guides to build an own private blockchain can be found here:

- Go-Ethereum: https://github.com/ethereum/go-ethereum
- Guide: https://medium.com/coinmonks/how-to-create-your-own-private-ethereum-blockchain-137ab15989c6

Example Genesis blocks of our implementation using Proof-of-Work and Proof-of-Authority as consensus mechanism can be found in the Contracts folder.

##Deploying Smart Contracts

There are multiple ways to deploy smart contracts on private Ethereum chains. Following this [guide](https://www.virtualforce.io/blockchain/create-deploy-your-first-smart-contract-on-private-blockchain/) you should be able to deploy our contract on your private Ethereum blockchain.
In order to use all functionalities of the market, the smart contracts needs to implement  our ERC20 Token which can be also found in the Contracts folder. To connect the market to the token, the address of the token smart contract has to be manually inserted into the market smart contract.
Other than this minor change, the source code of the token and the market mechanism can be copy/pasted.

## Interacting
By connecting your private blockchain to a GUI such as [Mist](https://github.com/ethereum/mist) allows you to easily interact with your smart contracts. Functions can be called and Events listened to. Now you can manually insert asks and bids and perform the first market auction.

## Simulation
All automated agents are written in Python. Necessary packages can be easily installed following the [Python protocol](https://packaging.python.org/tutorials/installing-packages/).






                            |



### A Full node on the Ethereum test network

Transitioning towards developers, if you'd like to play around with creating Ethereum
contracts, you almost certainly would like to do that without any real money involved until
you get the hang of the entire system. In other words, instead of attaching to the main
network, you want to join the **test** network with your node, which is fully equivalent to
the main network, but with play-Ether only.

```shell
$ geth --testnet console
```

The `console` subcommand has the exact same meaning as above and they are equally
useful on the testnet too. Please see above for their explanations if you've skipped here.

Specifying the `--testnet` flag, however, will reconfigure your `geth` instance a bit:

 * Instead of using the default data directory (`~/.ethereum` on Linux for example), `geth`
   will nest itself one level deeper into a `testnet` subfolder (`~/.ethereum/testnet` on
   Linux). Note, on OSX and Linux this also means that attaching to a running testnet node
   requires the use of a custom endpoint since `geth attach` will try to attach to a
   production node endpoint by default. E.g.
   `geth attach <datadir>/testnet/geth.ipc`. Windows users are not affected by
   this.
 * Instead of connecting the main Ethereum network, the client will connect to the test
   network, which uses different P2P bootnodes, different network IDs and genesis states.

*Note: Although there are some internal protective measures to prevent transactions from
crossing over between the main network and test network, you should make sure to always
use separate accounts for play-money and real-money. Unless you manually move
accounts, `geth` will by default correctly separate the two networks and will not make any
accounts available between them.*


### Programmatically interfacing `geth` nodes



HTTP based JSON-RPC API options:

  * `--rpc` Enable the HTTP-RPC server
  * `--rpcaddr` HTTP-RPC server listening interface (default: `localhost`)
  * `--rpcport` HTTP-RPC server listening port (default: `8545`)
  * `--rpcapi` API's offered over the HTTP-RPC interface (default: `eth,net,web3`)
  * `--rpccorsdomain` Comma separated list of domains from which to accept cross origin requests (browser enforced)
  * `--ws` Enable the WS-RPC server
  * `--wsaddr` WS-RPC server listening interface (default: `localhost`)
  * `--wsport` WS-RPC server listening port (default: `8546`)
  * `--wsapi` API's offered over the WS-RPC interface (default: `eth,net,web3`)
  * `--wsorigins` Origins from which to accept websockets requests
  * `--ipcdisable` Disable the IPC-RPC server
  * `--ipcapi` API's offered over the IPC-RPC interface (default: `admin,debug,eth,miner,net,personal,shh,txpool,web3`)
  * `--ipcpath` Filename for IPC socket/pipe within the datadir (explicit paths escape it)

You'll need to use your own programming environments' capabilities (libraries, tools, etc) to
connect via HTTP, WS or IPC to a `geth` node configured with the above flags and you'll
need to speak [JSON-RPC](https://www.jsonrpc.org/specification) on all transports. You
can reuse the same connection for multiple requests!

**Note: Please understand the security implications of opening up an HTTP/WS based
transport before doing so! Hackers on the internet are actively trying to subvert
Ethereum nodes with exposed APIs! Further, all browser tabs can access locally
running web servers, so malicious web pages could try to subvert locally available
APIs!**


#### Defining the private genesis state

First, you'll need to create the genesis state of your networks, which all nodes need to be
aware of and agree upon. This consists of a small JSON file (e.g. call it `genesis.json`):

```json
{
  "config": {
    "chainId": 0,
    "homesteadBlock": 0,
    "eip155Block": 0,
    "eip158Block": 0
  },
  "alloc": {},
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x20000",
  "extraData": "",
  "gasLimit": "0x2fefd8",
  "nonce": "0x0000000000000042",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x00"
}
```
