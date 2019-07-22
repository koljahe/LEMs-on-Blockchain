import time
import json
from web3.auto import w3
from web3.middleware import geth_poa_middleware
from random import randint
import math
from datetime import datetime, timedelta
import requests

w3.middleware_stack.inject(geth_poa_middleware, layer =0)

class LampAPI:

    def __init__(self):
        self.produrl = "https://hlaw3zg868.execute-api.eu-central-1.amazonaws.com/prod/market/graphql"
        self.devurl = "https://hlaw3zg868.execute-api.eu-central-1.amazonaws.com/dev/market/graphql"
        self.authdr = {"Authorization": "b2dcfe65-e0c9-4bb4-9ebd-cfddb987d090"}


    def get_prosumers_qry(self):
        qry = """
        {
          allUsers (filter: {userId: {equalTo: "2df75690-a771-11e8-b3ba-1feac1e2f5e2"}}){
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

#Deklarierung aller global benötigten Variablen
with open('ABItoken.json','r') as t:
    abi2 = json.load(t)

with open('ABImarket.json','r') as f:
    abi1 = json.load(f)

# Zugriff auf contracts & API ermöglichen
api = LampAPI()
is_dev = False
marketad = '0x75DBeE9debE9e1a5333a766651609779247CECa8' #per Hand ausfüllen
tokenad = '0xADD8b1d0d27e836624D8dDd7e4b376d61f9bCFa3'  #per Hand ausfüllen
userid = '2df75690-a771-11e8-b3ba-1feac1e2f5e2' #per Hand ausfüllen
fallbackpricehigh = 0
fallbackpricelow = 0
fee = 0
exchangerate = 200
market = w3.eth.contract(address = marketad, abi = abi1)
token = w3.eth.contract(address = tokenad, abi = abi2)
producer = None

def get_exchangerate():
    global exchangerate
    exchangerate = int(market.functions.getexchangerate().call({'from': w3.eth.coinbase}))

def update_fee():
    global fee
    fee = int(market.functions.getfee().call({'from': w3.eth.coinbase}))

def update_fallbackprices():
    global fallbackpricehigh
    global fallbackpricelow
    fallbackpricelow = int(market.functions.getfallbackPriceLow().call({'from': w3.eth.coinbase}))
    fallbackpricehigh = int(market.functions.getfallbackPriceHigh().call({'from': w3.eth.coinbase}))

def centinwei(cent):
    return int((((1*10**18)/exchangerate)/100000)*cent)

def try_parsing_date(text):
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f','%Y-%m-%dT%H:%M:%S'):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            pass
    raise ValueError('no valid date format found')

def update_all():
    get_exchangerate()
    update_fee()
    update_fallbackprices()

def call_query():
    global is_dev
    query = api.get_prosumers_qry()
    k = query[59:95]
    query = query.replace(k,userid)
    res = api.request_data(query, is_dev)
    data = dict(res['data'])
    return data

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

while (datetime.now() < datetime(2019,5,22,14,59)):
    time.sleep(1)

print("Schleife startet jetzt",datetime.now())

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
        watt = int(delta)#problem rundung
        wei = centinwei(price) #problem rundung
        w3.personal.unlockAccount(w3.eth.coinbase,'12345',0)
        try:
            token.functions.approve(marketad,watt).transact({'from': w3.eth.coinbase})
            print(datetime.now())
        except:
            print("Cannot approve tokens")

        while (datetime.now() < now + timedelta(seconds=17)):
            time.sleep(1)
        update_all()
        print(exchangerate)
        try:
            market.functions.addBid(watt,wei,producer.energytype).transact({'from': w3.eth.coinbase})
        except:
            print("Problem with addBid")
        producer.updateorder(price,amount,timestamp)
        print("Bid Placed: ",watt,price,datetime.now())
    else:
        print("no current Bid",datetime.now)
    print("")
    while (datetime.now() < now + timedelta(minutes=15)):
        time.sleep(1)
