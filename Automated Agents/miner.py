import time
import json
from web3.auto import w3
from web3.middleware import geth_poa_middleware
import math
import random
from datetime import datetime, timedelta


# Zugriff auf contracts & API ermöglichen
w3.middleware_stack.inject(geth_poa_middleware, layer =0)

w3.miner.start(1)
w3.miner.stop()
while (datetime.now() < datetime(2019,5,22,14,43,45)):
    time.sleep(1)

while True:
    aa = datetime.now()
    now = aa - timedelta(microseconds =aa.microsecond)
    w3.miner.start(1)
    print("Miner started",now)

    while(datetime.now() < now + timedelta(seconds=75)): #Jetzt 15.01
        time.sleep(1)

    w3.miner.stop()
    print("Miner stopped",datetime.now())

    while(datetime.now() < now + timedelta(minutes=15)):
        time.sleep(1)
