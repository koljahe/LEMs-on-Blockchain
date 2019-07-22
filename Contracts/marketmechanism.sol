pragma solidity ^0.4.21;

/// Importing the KITEnergyTokenInterface
/// @dev allowing the market mechanism to use functions of the KITEnergyToken
contract KITEnergyTokenInterface{
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function transfer(address to, uint tokens) public returns (bool success);
  function approve(address spender, uint tokens) public returns (bool success);
  function transferFrom(address from, address to, uint tokens) public returns (bool success);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success);
  }

/// ----------------------------------------------------------------------------
/// @title Ownable
/// @dev The Ownable contract has an owner address, and provides basic authorization control
/// functions, this simplifies the implementation of "user permissions".
/// ----------------------------------------------------------------------------
contract Ownable {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);


  /// @dev The Ownable constructor sets the original `owner` of the contract to the sender
  /// account.
  function Ownable() internal {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
  }


  /// @return the address of the owner.
  function owner() public view returns(address) {
    return _owner;
  }


  /// @dev Throws if called by any account other than the owner.
  modifier onlyOwner() {
    require(isOwner());
    _;
  }


  /// @return true if `msg.sender` is the owner of the contract.
  function isOwner() public view returns(bool) {
    return msg.sender == _owner;
  }


  /// @dev Allows the current owner to relinquish control of the contract.
  /// @notice Renouncing to ownership will leave the contract without an owner.
  /// It will not be possible to call the functions with the `onlyOwner`
  /// modifier anymore.
  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }


  /// @dev Allows the current owner to transfer control of the contract to a newOwner.
  /// @param newOwner The address to transfer ownership to.
  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }


  /// @dev Transfers control of the contract to a newOwner.
  /// @param newOwner The address to transfer ownership to.
  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0));
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
  }


/// ----------------------------------------------------------------------------
/// @author Kolja Heck
/// @title KIT Decentralized Energy Exchange
/// @dev Represents a decentralized market place performing a two-step
/// merit-order mechanism
/// ----------------------------------------------------------------------------
contract marketMechanism is Ownable{
uint fallbackPriceHigh = 2367;  // 23,67 Cent
uint fallbackPriceLow = 1200;   //12,00 Cent
uint match_id=0;
uint uniformPricePV = 0;
uint uniformPriceBHKW = 0;
uint lauf = 0;
uint8 pv  = 0;
uint8 bhkw = 0;
uint lastTriggerBlock = block.number;
uint matchAmount = 0;
uint trigger = 0;
address ckaddress = 0x3C6A2961F9D38b4cfbd0D03Cf4130b3Dc58618c4; // <-- manually change the address to your token address


/// Structs
/// @notice ElectricitytypeID = 1 --> Grey-Market(Grid), electricitytypeID = 2 --> PV,
/// electricitytypeID =  3 --> BHKW(CHP)
struct Ask {
  address asker;
  uint amount;
  uint price;
  uint8 energytype;
  string timestamp;
  }

struct Bid {
  address bidder;
  uint amount;
  uint pricepv;
  uint pricebhkw;
  uint8 preference;
  string timestamp;
  }

struct Match{
  address askaddress;
  address bidaddress;
  uint amount;
  uint8 energytype;
  string timestamp;
  }


/// Events
event AskPlaced (address asker, uint amount, uint price, uint8 energytype, string timestamp, uint lauf);
event BidPlaced (address bidder, uint amount, uint pricepv, uint pricebhkw, string timestamp,uint lauf);
event UniformPricePV (uint uniformPricePV, string timestamp, uint lauf);
event UniformPriceBHKW (uint uniformPriceBHKW, string timestamp, uint lauf);
event MatchMade (address asker, address bidder, uint amount, uint8 energytype, string timestamp, uint lauf);
event Transaction(address from, address to, string what, uint amount, uint lauf);
event UpdatePrice(uint oldprice, uint newprice, string which);
event ChangeofToken(address oldtoken, address ckaddress);


/// Mappings
/// @dev Every placed ask or bid is connected to the senders address and the addresses
/// are stored in an array
mapping(address => Ask) asks;
address[] public ask_ids;

mapping(address => Bid) bids;
address[] public bid_ids;

/// @dev Every match made is connected to an ID which is stored in an array
mapping(uint => Match) matches;
uint[] public match_ids;

/// @dev Locked value of all market participants is connected to their address
mapping(address => uint) remainingLockedValue;

///@dev Links KITEnergyTokenInterface to specific smart contract
KITEnergyTokenInterface energytoken = KITEnergyTokenInterface(ckaddress);

/// @dev Constructor of contract to equip the market place with ether
function marketMechanism() public payable{}

/// @dev Equip market place with more ether
/// @return boolean if transaction was successfull
function sendEther() public payable returns (bool success){
  return true;
  }

/// @dev Throws if Bid does not include sufficient amount of ether
modifier hasethBalance(uint _amount, uint _pricepv, uint _pricebhkw){
    uint _price = _pricebhkw;
    if (_pricepv > _pricebhkw){
      _price = _pricepv;
    }
    if(fallbackPriceHigh>_price){
      require((msg.value + remainingLockedValue[msg.sender])>=((fallbackPriceHigh)*_amount)*(10**14));
    }
    else{
      require((msg.value + remainingLockedValue[msg.sender])>=((_price)*_amount)*(10**14));
      }
      _;
    }

/// @dev Throws if Ask does not include sufficient amount of token
modifier hastokenBalance(uint _amount){
      require((energytoken.allowance(msg.sender,this) + remainingLockedValue[msg.sender])>=_amount);
  _;
  }

/// @dev Throws if minimal amount of blocks in between to two auctions
/// has not been mined
modifier isTrigger(){
  require(block.number>=lastTriggerBlock+trigger);
  _;
  }

/// @dev Creation of an Ask
/// @param _amount of electricity, _price which is asked for, _energytype that is sold,
/// _timestamp of ask
/// @notice A market participant can place an ask if no future bid has been made in
/// this trading period, empty asks are forbidden to be protected against DOS attacks
function addAsk (uint _amount, uint _price, uint8 _energytype, string _timestamp) public hastokenBalance(_amount){
  require(bids[msg.sender].amount==0);
  require(_amount > 0);
  if(asks[msg.sender].amount==0){
    Ask storage ask = asks[msg.sender];
    ask.asker = msg.sender;
    ask.amount = _amount;
    ask.price = _price;
    ask.energytype = _energytype;
    ask.timestamp = _timestamp;
    ask_ids.push(msg.sender)-1;
    remainingLockedValue[ask.asker]=_amount;
    energytoken.transferFrom(msg.sender,this,_amount);
  }
  else {
    Ask storage askUpdate = asks[msg.sender];
    askUpdate.amount = _amount;
    askUpdate.price = _price;
    askUpdate.energytype = _energytype;
    askUpdate.timestamp = _timestamp;
    asks[msg.sender] = askUpdate;

    if (_amount > remainingLockedValue[msg.sender]){
      energytoken.transferFrom(msg.sender,this,(_amount-remainingLockedValue[msg.sender]));
    }
    else{
      energytoken.transfer(msg.sender,(remainingLockedValue[msg.sender]-_amount));
    }
    remainingLockedValue[msg.sender]=_amount;
    }
    emit BidPlaced(msg.sender, _amount, _price, _energytype,_timestamp,lauf);
  }

/// @dev Creation of a Bid
/// @param _amount of electricity, _pricepv is the reservation price for PV-Energy,
/// _pricebhkw is the reservation price for CHP-Energy, _timestamp of bid
/// @notice A market participant can place an bid if no future ask has been made in t
/// his trading period, empty asks are forbidden to be protected against DOS attacks
function addBid (uint _amount, uint _pricepv, uint _pricebhkw, string _timestamp) public payable hasethBalance(_amount,_pricepv,_pricebhkw) {
    require(bids[msg.sender].amount==0);
    if(asks[msg.sender].amount==0){
      Ask storage ask = asks[msg.sender];
      ask.asker = msg.sender;
      ask.amount = _amount;
      ask.pricepv = _pricepv;
      ask.pricebhkw = _pricebhkw;
      ask.timestamp = _timestamp;
      if (_pricebhkw > _pricepv){
        bhkw++;
        ask.preference = 3;
      }
      if (_pricepv > _pricebhkw){
        pv++;
        ask.preference = 2;
      }
      ask_ids.push(msg.sender) -1;
      remainingLockedValue[msg.sender]=(msg.value);
    }
    else {
      Ask storage askUpdate= asks[msg.sender];
      askUpdate.amount = _amount;
      askUpdate.pricepv = _pricepv;
      askUpdate.pricebhkw = _pricebhkw;
      askUpdate.timestamp = _timestamp;
      if (_pricebhkw > _pricepv && askUpdate.preference == 2){
        bhkw++;
        pv--;
        askUpdate.preference = 3;
      }
      if(_pricebhkw < _pricepv && askUpdate.preference == 3){
        pv++;
        bhkw--;
        askUpdate.preference = 2;
      }

      asks[msg.sender] = askUpdate;

      uint _price = _pricebhkw;
      if (_pricepv > _pricebhkw){
        _price = _pricepv;
      }
      if(fallbackPriceHigh>_price){
        _price = fallbackPriceHigh;
      }

      if ((_price * 10**14 * _amount) < remainingLockedValue[msg.sender]){
        msg.sender.transfer(remainingLockedValue[msg.sender] - (_price * 10**14 * _amount));
        remainingLockedValue[msg.sender]= (_price * 10**14 * _amount);
      }
      else{
        remainingLockedValue[msg.sender]=(remainingLockedValue[msg.sender]+msg.value);
      }
    }
    emit BidPlaced (msg.sender, _amount, _pricepv, _pricebhkw, _timestamp,lauf);
  }



/// View functions

function getAllAsks() public view returns (address[]){
  return ask_ids;
  }

function getAskPreference(address _address) public view returns (uint){
  return asks[_address].preference;
  }

function getAskPricepv(address _address) public view returns (uint){
  return asks[_address].pricepv;
  }

function getAskPricebhkw(address _address) public view returns (uint){
  return asks[_address].pricebhkw;
  }

function getAskAmount(address _address) public view returns (uint){
  return asks[_address].amount;
  }

function getAskTimestamp(address _address) public view returns (string){
  return asks[_address].timestamp;
}

//Getter für Bids
function getAllBids() public view returns (address[]){
      return bid_ids;
    }

function getBidPrice(address _address) public view returns (uint){
  return bids[_address].price;
  }

function getBidAmount(address _address) public view returns (uint){
  return bids[_address].amount;
  }

function getBidEnergytype(address _address) public view returns (uint8){
  return bids[_address].energytype;
  }

function getBidTimestamp(address _address) public view returns (string){
  return bids[_address].timestamp;
}


//zusätzliche Getter Funktionen
function getremainingvalue (address _sender) public view returns(uint){
  return remainingLockedValue[_sender];
  }

function getfallbackPriceHigh() public view returns(uint){
  return fallbackPriceHigh;
  }

function getfallbackPriceLow() public view returns(uint){
  return fallbackPriceLow;
  }

/*function getfee() public view returns(uint){
  return fee;
  }
*/

function getMatches() public view returns (uint[]){
  return match_ids;
  }

//Getter für Uniform-Preise und Match-Präferenz
function getUniformpricePV () public view returns (uint) {
  return uniformPricePV;
  }

function getUniformpriceBHKW() public view returns (uint) {
      return uniformPriceBHKW;
  }

function getMatchPreference (uint a ) public view returns (uint8){
  return matches[match_ids[a]].energytype;
  }

//function um bei Bids und Asks zu prüfen, ob auch die Auction getriggered werden soll
function getBoolean() public view returns(bool){
    if(block.number>=lastTriggerBlock+trigger){
        return true;
    }
  }


//Update Functions
function changeTokenAddress(address _token) public onlyOwner returns (bool){
  address oldtoken = ckaddress;
  ckaddress = _token;
  emit ChangeofToken(oldtoken,ckaddress);
  return true;
}

function updateFallbackPriceHigh(uint _fallbackpricehigh) public onlyOwner returns (bool){ //reihenfolge checken und owner implementieren
    uint r = fallbackPriceHigh;
    fallbackPriceHigh = _fallbackpricehigh;
    emit UpdatePrice(r,fallbackPriceHigh,"fallbackpricehigh");
    return true;
  }

function updateFallbackPriceLow(uint _fallbackpricelow) public onlyOwner returns (bool) { //reihenfolge checken und owner implementieren
    uint r = fallbackPriceLow;
    fallbackPriceLow = _fallbackpricelow;
    emit UpdatePrice(r,fallbackPriceLow,"fallbackpricelow");
    return true;
  }

//Verstellung des Abstands zwischen zwei auctions
function setTrigger(uint t) public onlyOwner returns(bool) {
  trigger = t;
  return true;
  }

/*function updatefee(uint _fee) public onlyOwner returns(bool){
  uint oldfee = fee;
  fee = _fee;
  emit UpdatePrice(oldfee,fee,"fee");
  }
*/

//Sortierung der Bids aufsteigend
function sort_arrayauf() private{
    uint256 l = bid_ids.length;
    for(uint i = 0; i < l; i++) {
        for(uint j = i+1; j < l ;j++) {
            if(getBidPrice(bid_ids[i]) > getBidPrice(bid_ids[j])) {
                address temp = bid_ids[i];
                bid_ids[i] = bid_ids[j];
                bid_ids[j] = temp;
            }
        }
    }
  }

//Sortierung der Asks absteigend nach pricepv
function sort_arrayabpv() private{
    uint256 l = ask_ids.length;
    for(uint i = 0; i < l; i++) {
        for(uint j = i+1; j < l ;j++) {
            if(getAskPricepv(ask_ids[i]) < getAskPricepv(ask_ids[j])) {
                address temp = ask_ids[i];
                ask_ids[i] = ask_ids[j];
                ask_ids[j] = temp;
            }
        }
    }
  }

//Sortierung der Asks absteigend nach pricebhkw
function sort_arrayabbhkw() private{
    uint256 l = ask_ids.length;
    for(uint i = 0; i < l; i++) {
        for(uint j = i+1; j < l ;j++) {
            if(getAskPricebhkw(ask_ids[i]) < getAskPricebhkw(ask_ids[j])) {
                address temp = ask_ids[i];
                ask_ids[i] = ask_ids[j];
                ask_ids[j] = temp;
            }
        }
    }
  }


function try_to_auction() public isTrigger{
  //Auslösung der Sortierungen der Bids und Asks, sowie Auslösung der Auction
  lastTriggerBlock=block.number;  //wenn auction getriggered wird, dann speichern wir den aktuelllen block
  reset_before();
  if(bhkw > pv){
    sort_arrayabbhkw();
    sort_arrayauf(); // bei Funktion dann is trigger aufrufen? Aber dann wird der teil hier jedes Mal ausgeführt. so nicht!
    bhkwmatching();
    sort_arrayabpv();
    pvmatching();
    }
  else{
    sort_arrayabpv();
    sort_arrayauf();
    pvmatching();
    sort_arrayabbhkw();
    bhkwmatching();
    }
  rest_of_auction();
  //matchingTransactions();
  reset_after();
    }

//Matching im PV Markt
function pvmatching() private{
  for (uint i=0; i<bid_ids.length; i++) { //alle Bids durchgehen
      for(uint j = 0; j< ask_ids.length; j++){  //alle Asks durchgehen
          if(getBidAmount(bid_ids[i])>0 && getBidEnergytype(bid_ids[i])==2){  //Angebot >0 und PV
          if(getAskAmount(ask_ids[j]) > 0){ //Nachfrage >0 und PV
          if(getBidPrice(bid_ids[i]) <= getAskPricepv(ask_ids[j])){ //Angebotspreis kleiner gleich Nachfragepreis
             if(getAskAmount(ask_ids[j]) <= getBidAmount(bid_ids[i])){  //Nachfragemenge kleiner gleich Angebotsmenge
                 matchAmount = getAskAmount(ask_ids[j]);  //dann ist Nachfragemenge die gematchte Menge
             }else{
                 matchAmount = getBidAmount(bid_ids[i]);  //sonst wird Nachfrage mit restlicher Angebotsmenge teilbefüllt
             }
             if(matchAmount > 0){ //wenn Matchamount >0 ist wird ein Match erstellt
                 Match storage _matchPV = matches[match_id];
                 _matchPV.bidaddress = bid_ids[i];
                 _matchPV.askaddress = ask_ids[j];
                 _matchPV.amount = matchAmount;
                 _matchPV.energytype = 2;
                 _matchPV.timestamp = getBidTimestamp(bid_ids[i]);
                 asks[ask_ids[j]].amount = getAskAmount(ask_ids[j]) - matchAmount; //matchAmount von Ask Amount abziehen
                 bids[bid_ids[i]].amount = getBidAmount(bid_ids[i]) - matchAmount; //matchAmount von Bid Amount abziehen
                 match_ids.push(match_id) -1;
                 match_id++;

                 emit MatchMade(bid_ids[i],ask_ids[j],matchAmount,2, getBidTimestamp(bid_ids[i]),lauf);
             }
          }
          }
        }
      }
    }
/*
  //Berechnung des UniformPricePV: der höchste noch gematchte Bid-Preis in PV ist der uniformPricePV
  for(uint x = 0; x < match_ids.length; x++){ // ins bhkw array hinzufügen 9
    if(getMatchPreference(x)==2){
      if(getBidPrice(matches[match_ids[x]].bidaddress)>uniformPricePV){
          uniformPricePV = getBidPrice(matches[match_ids[x]].bidaddress);
      }
    }
  }*/
  //emit UniformPricePV (uniformPricePV,getBidTimestamp(matches[match_ids[x]].bidaddress),lauf);
  }

function bhkwmatching () private {
  //Matching im BHKW Markt, analog zu PV
  for (uint i=0; i<bid_ids.length; i++) {
          for(uint j = 0; j< ask_ids.length; j++){
            if(getBidAmount(bid_ids[i])>0 && getBidEnergytype(bid_ids[i])==3){ //wenn preference nicht Grey, damit Rest aus PV und BHKW gematched wird
            if(getAskAmount(ask_ids[j]) > 0){
            if(getBidPrice(bid_ids[i]) <= getAskPricebhkw(ask_ids[j])){
                  if(getAskAmount(ask_ids[j]) <= getBidAmount(bid_ids[i])){
                      matchAmount = getAskAmount(ask_ids[j]);
                  }else{
                      matchAmount = getBidAmount(bid_ids[i]);
                  }
                  if(matchAmount > 0){
                       Match storage _matchbhkw = matches[match_id];
                       _matchbhkw.bidaddress = bid_ids[i];
                       _matchbhkw.askaddress = ask_ids[j];
                       _matchbhkw.amount = matchAmount;
                       _matchbhkw.timestamp = getBidTimestamp(bid_ids[i]);
                       _matchbhkw.energytype = 3;
                       asks[ask_ids[j]].amount = getAskAmount(ask_ids[j]) - matchAmount;
                       bids[bid_ids[i]].amount = getBidAmount(bid_ids[i]) - matchAmount;
                       match_ids.push(match_id) -1;
                       match_id++;

                       emit MatchMade(bids[bid_ids[i]].bidder,asks[ask_ids[j]].asker,matchAmount,3,getBidTimestamp(bid_ids[i]),lauf);
                  }
             }
             }
          }
        }
      }

/*
  //Berechnung des UniformPriceBHKW: der höchste noch gematchte Bid-Preis in PV ist der uniformPriceBHKW
  for(uint x = 0; x < match_ids.length; x++){ //zu BHKW matching hinzufügen --> kürzeres array --> günstiger
    if(getMatchPreference(x)==3){
      if(getBidPrice(matches[match_ids[x]].bidaddress)>uniformPriceBHKW){
          uniformPriceBHKW = getBidPrice(matches[match_ids[x]].bidaddress);
      }
    }
  }*/
//  emit UniformPriceBHKW (uniformPriceBHKW,getBidTimestamp(matches[match_ids[x]].bidaddress),lauf);
  }

function rest_of_auction() private{
  //Matching im GreyMarket mit den restlichen Angebotsmengen, Ask wird hier vom GreyMarket gestellt
  for(uint i = 0; i < bid_ids.length; i++){
    if(getBidAmount(bid_ids[i]) > 0){
      matchAmount = getBidAmount(bid_ids[i]);
      Match storage matchGrey1 = matches[match_id];

      Ask storage greyAsk = asks[this];
      greyAsk.asker = this;
      greyAsk.amount = matchAmount;
      greyAsk.pricepv = fallbackPriceLow;
      greyAsk.pricebhkw = fallbackPriceLow;
      greyAsk.timestamp = getBidTimestamp(bid_ids[i]);
      greyAsk.preference = 1;
      remainingLockedValue[greyAsk.asker] = 0;
      emit AskPlaced(this,matchAmount,fallbackPriceLow,1,getBidTimestamp(bid_ids[i]),lauf);

      matchGrey1.bidaddress = bid_ids[i];
      matchGrey1.askaddress = this;
      matchGrey1.amount = matchAmount;
      matchGrey1.energytype = 1;
      matchGrey1.timestamp = getBidTimestamp(bid_ids[i]);
      match_ids.push(match_id) -1;
      bids[bid_ids[i]].amount = getBidAmount(bid_ids[i]) - matchAmount;
      match_id++;

      emit MatchMade(bids[bid_ids[i]].bidder,greyAsk.asker,matchAmount,1,getBidTimestamp(bid_ids[i]),lauf);
      }
    }

  //Matching im GreyMarket mit den restlichen Nachfragemengen, Bid wird hier vom GreyMarket gestellt
  for(uint j = 0; j < ask_ids.length; j++){
    if(getAskAmount(ask_ids[j]) > 0){
      matchAmount = getAskAmount(ask_ids[j]);
      Match storage matchGrey2 = matches[match_id];

      Bid storage greyBid = bids[this];
      greyBid.bidder = this;
      greyBid.amount = matchAmount;
      greyBid.price = fallbackPriceHigh;
      greyBid.timestamp = getAskTimestamp(ask_ids[j]);
      greyBid.energytype = 1;
      remainingLockedValue[greyBid.bidder]=0;
      emit BidPlaced(this,matchAmount,fallbackPriceHigh,1,getAskTimestamp(ask_ids[j]),lauf);

      matchGrey2.askaddress = ask_ids[j];
      matchGrey2.bidaddress = this;
      matchGrey2.amount = matchAmount;
      matchGrey2.energytype = 4;
      matchGrey2.timestamp = getAskTimestamp(ask_ids[j]);
      match_ids.push(match_id) -1;
      asks[ask_ids[j]].amount = getAskAmount(ask_ids[j]) - matchAmount;
      match_id++;

      emit MatchMade(greyBid.bidder,asks[ask_ids[j]].asker,matchAmount,1,getAskTimestamp(ask_ids[j]),lauf);

      }
    }
  }


// teilen durch 100 eventuell weglassen damit kein type force


//Transaktionen
function matchingTransactions() private {
    //Transaktionen für PV
    for(uint z = 0; z < match_ids.length; z++){
      if(getMatchPreference(z)==2){
        energytoken.transfer(matches[match_ids[z]].askaddress,(matches[match_ids[z]].amount)); // Asker bekommt token vom contract (die wir vom Bidder bekommen haben)
        matches[match_ids[z]].bidaddress.transfer(matches[match_ids[z]].amount*getUniformpricePV()*(10**14)); //Bidder bekommt eth vom contract (die wir vom Asker bekommen haben)
        remainingLockedValue[matches[match_ids[z]].askaddress] = remainingLockedValue[matches[match_ids[z]].askaddress] - (matches[match_ids[z]].amount * getUniformpricePV()* (10**14)); //remainingLockedValue wird um Transaktionsvolumen reduziert
        emit Transaction(matches[match_ids[z]].askaddress,matches[match_ids[z]].bidaddress,"Cent*100",matches[match_ids[z]].amount*getUniformpricePV(),lauf);
        remainingLockedValue[matches[match_ids[z]].bidaddress] = remainingLockedValue[matches[match_ids[z]].bidaddress] - (matches[match_ids[z]].amount); //remainingLockedValue wird um Transaktionsvolumen reduziert
        emit Transaction(matches[match_ids[z]].bidaddress,matches[match_ids[z]].askaddress,"Token",matches[match_ids[z]].amount,lauf);
      }
    }
    z=0;

    //Transaktionen für BHKW, analog zu PV
    for(z = 0; z < match_ids.length; z++){
      if(getMatchPreference(z)==3){
        energytoken.transfer(matches[match_ids[z]].askaddress,(matches[match_ids[z]].amount));
        matches[match_ids[z]].bidaddress.transfer(matches[match_ids[z]].amount*getUniformpriceBHKW()*(10**14));
        remainingLockedValue[matches[match_ids[z]].askaddress] = remainingLockedValue[matches[match_ids[z]].askaddress] - (matches[match_ids[z]].amount*getUniformpriceBHKW()*(10**14));
        emit Transaction(matches[match_ids[z]].askaddress,matches[match_ids[z]].bidaddress,"Cent*100",matches[match_ids[z]].amount*getUniformpriceBHKW(),lauf);
        remainingLockedValue[matches[match_ids[z]].bidaddress] = remainingLockedValue[matches[match_ids[z]].bidaddress] - (matches[match_ids[z]].amount);
        emit Transaction(matches[match_ids[z]].bidaddress,matches[match_ids[z]].askaddress,"Token",matches[match_ids[z]].amount,lauf);
      }
    }
    z=0;

    //Transaktionen für Grey bei GreyMarket als Ask
    for(z = 0; z < match_ids.length; z++){
      if(getMatchPreference(z)==1){
        emit Transaction(matches[match_ids[z]].bidaddress,matches[match_ids[z]].askaddress,"Token",matches[match_ids[z]].amount,lauf);
        matches[match_ids[z]].bidaddress.transfer(matches[match_ids[z]].amount*fallbackPriceLow*(10**14));
        remainingLockedValue[matches[match_ids[z]].bidaddress] = remainingLockedValue[matches[match_ids[z]].bidaddress] - (matches[match_ids[z]].amount);
        emit Transaction(matches[match_ids[z]].askaddress,matches[match_ids[z]].bidaddress,"Cent*100",matches[match_ids[z]].amount*fallbackPriceLow,lauf);
      }
    }
    z=0;

    //Transaktionen für Grey bei GreyMarket als Bid
    for(z = 0; z < match_ids.length; z++){
      if(getMatchPreference(z)==4){
        energytoken.transfer(matches[match_ids[z]].askaddress,(matches[match_ids[z]].amount));
        remainingLockedValue[matches[match_ids[z]].askaddress] = remainingLockedValue[matches[match_ids[z]].askaddress] - (matches[match_ids[z]].amount*fallbackPriceHigh*(10**14));
        emit Transaction(matches[match_ids[z]].bidaddress,matches[match_ids[z]].askaddress,"Token",matches[match_ids[z]].amount,lauf);
        emit Transaction(matches[match_ids[z]].askaddress,matches[match_ids[z]].bidaddress,"Cent*100",matches[match_ids[z]].amount*fallbackPriceHigh,lauf);
      }
    }
    z=0;


    //Zurückzahlungen falls gesperrter betrag höher ist als tatsächlich gezahlter Betrag und löschen der mappings & arrays
    for(z = 0; z < match_ids.length; z++){
         if(remainingLockedValue[matches[match_ids[z]].askaddress]>0){
           matches[match_ids[z]].askaddress.transfer(remainingLockedValue[matches[match_ids[z]].askaddress]);
           emit Transaction(this,matches[match_ids[z]].askaddress,"Rückzahlung Wei",remainingLockedValue[matches[match_ids[z]].askaddress],lauf);
           remainingLockedValue[matches[match_ids[z]].askaddress] = 0;
         }
       }
    }

function reset_after() private {
    delete bid_ids;
    delete ask_ids;
    pv = 0;
    bhkw = 0;
    lauf++;
  }

function reset_before() private{
    delete match_ids;
    match_id = 0;
    uniformPricePV = 0;
    uniformPriceBHKW = 0;

}

}
