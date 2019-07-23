import time
from web3.auto import w3
from web3.middleware import geth_poa_middleware
from datetime import datetime, timedelta


# Only needed when using a PoA private blockchain
# Allows access to private chain
w3.middleware_stack.inject(geth_poa_middleware, layer =0)

# Waits until first market closing time is reached and miners have to start to
# transact all incoming information
while (datetime.now() < datetime(2019,5,22,14,43,45)):
    time.sleep(1)

#Starts and stops miner after a fixed time interval for every auction
while True:
    aa = datetime.now()
    now = aa - timedelta(microseconds =aa.microsecond)
    w3.miner.start(1)
    print("Miner started",now)

    while(datetime.now() < now + timedelta(seconds=75)):
        time.sleep(1)

    w3.miner.stop()
    print("Miner stopped",datetime.now())

    while(datetime.now() < now + timedelta(minutes=15)):
        time.sleep(1)
