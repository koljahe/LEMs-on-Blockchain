import time
import json
from web3.auto import w3
from web3.middleware import geth_poa_middleware
from random import randint
import math
from datetime import datetime, timedelta
import requests

# Only needed when using a PoA private blockchain
# Allows access to private chain
w3.middleware_stack.inject(geth_poa_middleware, layer =0)

# API to access LAMP data
class LampAPI:

    def __init__(self):
        self.produrl = ""
        self.devurl = ""
        self.authdr = {"Authorization": ""}


    def get_prosumers_qry(self):
        qry = """
        {
          allUsers (filter: {userId: {equalTo: ""}}){
            nodes {
              nodeId
              userId
              sbUserId
            }
            edges {
              node {
                sbUserId
                userId
                createdAt
                updatedAt
                smartMetersByFkUserId {
                  edges {
                    node {
                      fkUserId
                      fkElectricityTypeId
                      electricityTypeByFkElectricityTypeId {
                        electricityTypeId
                        name
                      }
                      isProduction
                      smartMeterId
                      smartMeterSerialNumber
                      energyTurnoversByFkSmartMeterId(first: 1, orderBy:TIMESTAMP_DESC) {
                        nodes {
                          fkSmartMeterId
                          amount
                          timestamp
                        }
                      }
                      createdAt
                      updatedAt
                    }
                  }
                }
                buyPreferencePV: bidsByFkUserId(first: 1, orderBy:TIMESTAMP_DESC, condition: {isSeller: false, fkElectricityTypeId: 2}) {
                  edges {
                    node {
                      ...bidFields
                    }
                  }
                }
                buyPreferenceBHKW: bidsByFkUserId(first: 1, orderBy:TIMESTAMP_DESC, condition: {isSeller: false, fkElectricityTypeId: 3}) {
                  edges {
                    node {
                      ...bidFields
                    }
                  }
                }
                sellPreferencePV: bidsByFkUserId(first: 1, orderBy:TIMESTAMP_DESC, condition: {isSeller: true, fkElectricityTypeId: 2}) {
                  edges {
                    node {
                      ...bidFields
                    }
                  }
                }
                sellPreferenceBHKW: bidsByFkUserId(first: 1, orderBy:TIMESTAMP_DESC, condition: {isSeller: true, fkElectricityTypeId: 3}) {
                  edges {
                    node {
                      ...bidFields
                    }
                  }
                }
              }
            }
          }
        }

        fragment bidFields on Bid {
          fkUserId
          bidId
          fkElectricityTypeId
          isSeller
          timestamp
          price
          intervalId
          createdAt
          updatedAt
        }
        """
        return qry



    def post_request(self, qry, url, hdr):
        req = requests.post(url, json={'query': qry}, headers=hdr)

        if req.status_code == 200:
            return req.json()
        else:
            raise Exception("Query failed: {}. {}".format(req.status_code, query))


    def request_data(self, qry, is_dev):
        hdr = self.authdr
        url = self.produrl
        if (is_dev):
            url = self.devurl

        return self.post_request(qry, url, hdr)

# Defines all attributes of a producer and safes information about latest ask
class Producer:
    def __init__(self,userid,energytype,amount,price,timestamp):
        self.userid = userid
        self.energytype = energytype
        self.amount = amount
        self.price = price
        self.timestamp = timestamp

    def updateorder(self,price,amount,timestamp):
        self.price = price
        self.amount = amount
        self.timestamp = timestamp

# Importing ABIs of smart contracts to correctly call functions
with open('ABItoken.json','r') as t:
    abi2 = json.load(t)

with open('ABImarket.json','r') as f:
    abi1 = json.load(f)

# Access to LampAPI
api = LampAPI()
is_dev = False
userid = ''

# Access to smart contracts
marketad = '0x75DBeE9debE9e1a5333a766651609779247CECa8' # Has to be manually inserted
tokenad = '0xADD8b1d0d27e836624D8dDd7e4b376d61f9bCFa3'  # Has to be manually inserted
market = w3.eth.contract(address = marketad, abi = abi1)
token = w3.eth.contract(address = tokenad, abi = abi2)

fallbackpricehigh = 0
fallbackpricelow = 0
producer = None

# Recieve current fallback prices from market mechanism
def update_fallbackprices():
    global fallbackpricehigh
    global fallbackpricelow
    fallbackpricelow = int(market.functions.getfallbackPriceLow().call({'from': w3.eth.coinbase}))
    fallbackpricehigh = int(market.functions.getfallbackPriceHigh().call({'from': w3.eth.coinbase}))

# Parsing date into fitting format
def try_parsing_date(text):
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f','%Y-%m-%dT%H:%M:%S'):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            pass
    raise ValueError('no valid date format found')

# Accessing data from LAMP
def call_query():
    global is_dev
    query = api.get_prosumers_qry()
    k = query[59:95]
    query = query.replace(k,userid)
    res = api.request_data(query, is_dev)
    data = dict(res['data'])
    return data

# Create a new producer and insert all current information from data query
def create_producer():
    global userid
    global producer
    x = call_query()
    timestamp = try_parsing_date(x["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["timestamp"][:-6])
    energytype = int(x["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["electricityTypeByFkElectricityTypeId"]["electricityTypeId"])
    amount = x["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["amount"]
    if (energytype == 2):
        price = x["allUsers"]["edges"][0]["node"]["sellPreferencePV"]["edges"][0]["node"]["price"]
    elif(energytype == 3):
        price = x["allUsers"]["edges"][0]["node"]["sellPreferenceBHKW"]["edges"][0]["node"]["price"]
    else:
        print("Nicht BHKW oder PV")
    print(amount,energytype,price,userid,timestamp)
    producer = Producer(userid,energytype,amount,price,timestamp)


create_producer()
# Wait until first bid has to be placed
while (datetime.now() < datetime(2019,5,22,14,59)):
    time.sleep(1)

print("Schleife startet jetzt",datetime.now())

# For every trading period current information is pulled from the database
# the producer updates its ask and places it in the market
while True:
    aa = datetime.now()
    now  = aa - timedelta(microseconds =aa.microsecond)
    lastamount = producer.amount
    lastprice = producer.price
    query = call_query()
    timestamp = try_parsing_date(query["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["timestamp"][:-6])
    if (timestamp > now - timedelta(minutes=15) and timestamp > producer.timestamp):
        amount = query["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["amount"]
        if (producer.energytype == 2):
            price = query["allUsers"]["edges"][0]["node"]["sellPreferencePV"]["edges"][0]["node"]["price"]
        elif(producer.energytype == 3):
            price = query["allUsers"]["edges"][0]["node"]["sellPreferenceBHKW"]["edges"][0]["node"]["price"]
        delta = (amount*1000) - (lastamount*1000)
        watt = int(delta)
        price = price * 100
        w3.personal.unlockAccount(w3.eth.coinbase,'12345',0)
        try:
            token.functions.approve(marketad,watt).transact({'from': w3.eth.coinbase})
            print(datetime.now())
        except:
            print("Cannot approve tokens")

        while (datetime.now() < now + timedelta(seconds=17)):
            time.sleep(1)
        update_fallbackprices()
        try:
            market.functions.addAsk(watt,price,producer.energytype).transact({'from': w3.eth.coinbase})
        except:
            print("Problem with addBid")
        producer.updateorder(price,amount,timestamp)
        print("Bid Placed: ",watt,price,datetime.now())
    else:
        print("no current Bid",datetime.now)
    print("")
    while (datetime.now() < now + timedelta(minutes=15)):
        time.sleep(1)
