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
        self.produrl = ""
        self.devurl = ""
        self.authdr = {"Authorization": ""}


    def get_prosumers_qry(self):
        qry = """
        {
          allUsers (filter: {userId: {equalTo: "7ed3f936-a796-11e8-9ff3-2751d48c135d"}}){
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

class Consumer:
    def __init__(self,userid,amount,pricepv,pricebhkw,timestamp):
        self.userid = userid
        self.amount = amount
        self.pricepv = pricepv
        self.pricebhkw = pricebhkw
        self.timestamp = timestamp

    def updateorder(self,pricepv,pricebhkw,amount,timestamp):
        self.pricepv = pricepv
        self.pricebhkw = pricebhkw
        self.amount = amount
        self.timestamp = timestamp

#Deklarierung aller global benötigten Variablen
with open('ABImarket.json','r') as f:
    abi1 = json.load(f)

# Zugriff auf contracts & API ermöglichen
api = LampAPI()
is_dev = False
x = 3
marketad = '0x75DBeE9debE9e1a5333a766651609779247CECa8' #per Hand ausfüllen
userids = ['1aed8a26-a797-11e8-9959-673b7efc7e5d','7ed3f936-a796-11e8-9ff3-2751d48c135d','e4daafb8-a796-11e8-84d5-4f3c129b2f51','f410927c-a796-11e8-81c3-ef639c1b83b3']
userid = userids[x]
fallbackpricehigh = 0
fallbackpricelow = 0
fee = 0
exchangerate = 200
market = w3.eth.contract(address = marketad, abi = abi1)
consumer = None

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

def get_sum(watt ,_pricepv,_pricebhkw):
    _price = _pricebhkw
    if (_pricepv > _pricebhkw):
      _price = _pricepv
    if(fallbackpricehigh>_price):
        sum = ((fallbackpricehigh+fee)*watt)
    else:
        sum =((_price+fee)*watt)
    return sum

def call_query():
    global is_dev
    query = api.get_prosumers_qry()
    k = query[59:95]
    query = query.replace(k,userid)
    res = api.request_data(query, is_dev)
    data = dict(res['data'])
    return data

def create_consumer():
    global userid
    global consumer
    x = call_query()
    timestamp = try_parsing_date(x["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["timestamp"][:-6])
    amount = x["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["amount"]
    pricepv = x["allUsers"]["edges"][0]["node"]["buyPreferencePV"]["edges"][0]["node"]["price"]
    pricebhkw = x["allUsers"]["edges"][0]["node"]["buyPreferenceBHKW"]["edges"][0]["node"]["price"]
    print(amount,pricepv,pricebhkw,userid,timestamp)
    consumer = Consumer(userid,amount,pricepv,pricebhkw,timestamp)

create_consumer()

while (datetime.now() < datetime(2019,5,22,14,59,17)):
    time.sleep(1)

print("Schleife startet jetzt",datetime.now())

while True:
    aa = datetime.now()
    now  = aa  - timedelta(microseconds =aa.microsecond)
    update_all()
    lastamount = consumer.amount
    lastpricepv = consumer.pricepv
    lastpricebhkw = consumer.pricebhkw
    query = call_query()
    timestamp = try_parsing_date(query["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["timestamp"][:-6])
    print(timestamp)
    if (timestamp > now - timedelta(minutes=15) and timestamp > consumer.timestamp):
        amount = query["allUsers"]["edges"][0]["node"]["smartMetersByFkUserId"]["edges"][0]["node"]["energyTurnoversByFkSmartMeterId"]["nodes"][0]["amount"]
        pricepv = query["allUsers"]["edges"][0]["node"]["buyPreferencePV"]["edges"][0]["node"]["price"]
        pricebhkw = query["allUsers"]["edges"][0]["node"]["buyPreferenceBHKW"]["edges"][0]["node"]["price"]
        delta = (amount*1000) - (lastamount*1000)
        watt = int(delta)#problem rundung
        weipv = centinwei(pricepv) #problem rundung
        weibhkw = centinwei(pricebhkw) #problem rundung
        sum = get_sum(watt,weipv,weibhkw)
        w3.personal.unlockAccount(w3.eth.coinbase,'12345',0)
        try:
            market.functions.addAsk(watt,weipv,weibhkw).transact({'from': w3.eth.coinbase,'value':(sum)})
        except:
            print("Problem with addAsk")
        consumer.updateorder(pricepv,pricebhkw,amount,timestamp)
        print("Ask Placed: ",watt,pricepv,pricebhkw,datetime.now())
    else:
        print("no current Ask",datetime.now())
    print()
    while (datetime.now() < now + timedelta(minutes=15)):
        time.sleep(1)
