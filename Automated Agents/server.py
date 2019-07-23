import time
import json
from web3.auto import w3
from web3.middleware import geth_poa_middleware
import math
import random
from datetime import datetime, timedelta
from cryptowatch_client import Client

#Grants access to smart contract of the market mechanism
with open('ABImarket.json','r') as f:
    abi1 = json.load(f)

# Only needed when using a PoA private blockchain
# Allows access to private chain
w3.middleware_stack.inject(geth_poa_middleware, layer =0)

#Needs to be filled manually
marketad = '0x75DBeE9debE9e1a5333a766651609779247CECa8'
market = w3.eth.contract(address = marketad, abi = abi1)

# Waits until first market closing time is reached and transactions are executed
while (datetime.now() < datetime(2019,5,22,16,43,45)):
    time.sleep(1)

# Calls the auction function for every trading period
# Waits a fixed time interval for next auction 
while True:
    aa = datetime.now()
    now = aa - timedelta(microseconds =aa.microsecond)
    w3.miner.start(1)
    print("Miner started",now)

    while(datetime.now() < now + timedelta(seconds=63)):
        time.sleep(1)
    print("Function Calls",datetime.now()) # Soll 14.50
    try:
        w3.personal.unlockAccount(w3.eth.coinbase,'12345',0)
        market.functions.try_to_auction().transact({'from': w3.eth.coinbase})
        print("Auction startet",datetime.now())
    except:
        print("cannot start auction")

    while(datetime.now() < now + timedelta(seconds=75)):
        time.sleep(1)

    w3.miner.stop()
    print("Miner stopped",datetime.now())

    while(datetime.now() < now + timedelta(minutes=15)):
        time.sleep(1)
