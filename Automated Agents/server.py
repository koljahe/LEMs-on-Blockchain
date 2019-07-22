import time
import json
from web3.auto import w3
from web3.middleware import geth_poa_middleware
import math
import random
from datetime import datetime, timedelta
from cryptowatch_client import Client

with open('ABImarket.json','r') as f:
    abi1 = json.load(f)

# Zugriff auf contracts & API ermöglichen
w3.middleware_stack.inject(geth_poa_middleware, layer =0)
marketad = '0x75DBeE9debE9e1a5333a766651609779247CECa8' #per Hand ausfüllen
market = w3.eth.contract(address = marketad, abi = abi1)
fallbackpricehigh = 0
fallbackpricelow = 0
fee = 0
exchangerate = 227

def get_exchangerate():
    global exchangerate
    client = Client()
    raw = client.get_markets_price(exchange='gdax', pair='etheur')
    data1 = raw.json()
    data = dict(data1['result'])
    exchangerate = int(data['price']) #Auf integer gerundet

def update_fee(price):
    global fee
    fee = int(((1*10**18)/price)/50000)
    return fee

def update_fallbackprices(price):
    global fallbackpricehigh
    global fallbackpricelow
    fallbackpricelow = int((((1*10**18)/price)/100000)*12)
    fallbackpricehigh =int((((1*10**18)/price)/10000000)*2667)

def update_all():
    try:
        get_exchangerate()
    except:
        print("Server-Anfrage geht nicht durch",exchangerate)
    update_fee(exchangerate)
    update_fallbackprices(exchangerate)
    w3.personal.unlockAccount(w3.eth.coinbase,'12345',0)
    market.functions.updateFallbackPriceHigh(fallbackpricehigh).transact({'from': w3.eth.coinbase})
    market.functions.updateFallbackPriceLow(fallbackpricelow).transact({'from': w3.eth.coinbase})
    market.functions.updateexchangerate(exchangerate).transact({'from': w3.eth.coinbase})
    market.functions.updatefee(fee).transact({'from': w3.eth.coinbase})


w3.miner.start(1)
w3.miner.stop()

while (datetime.now() < datetime(2019,5,22,16,43,45)):
    time.sleep(1)

while True:
    aa = datetime.now()
    now = aa - timedelta(microseconds =aa.microsecond)
    w3.miner.start(1)
    print("Miner started",now)
    update_all() #nur aifb server
    print(exchangerate,fallbackpricehigh,fallbackpricelow,fee)

    while(datetime.now() < now + timedelta(seconds=63)): #Jetzt 14.48
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
