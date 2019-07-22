pragma solidity ^0.4.21;

// ----------------------------------------------------------------------------
// KIT Energy Token
// ERC20 Standard Token
// Represents electricity in kWh
//
// Symbol      : KIET
// Name        : KIT Energy Token
// Total supply: 1,000,000.000
// Decimals    : 3
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Burn(address indexed from, uint256 value);
}

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}


// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals and a
// fixed supply
// ----------------------------------------------------------------------------
contract KITEnergyToken is ERC20Interface, Owned {
    using SafeMath for uint;

    string public symbol;
    string public  name;
    uint8 public decimals;
    uint _totalSupply;

    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;
    mapping (address => bool) public frozenAccount;

    event FrozenFunds(address target, bool frozen);


    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function KITEnergyToken() public {
        symbol = "EnergyKIT";
        name = "KIT Energy Token";
        decimals = 3;
        _totalSupply = 1000000 * 10**uint(decimals);
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }


    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public view returns (uint) {
        return _totalSupply.sub(balances[address(0)]);
    }


    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    // ------------------------------------------------------------------------
    // Internal transfer function with all requirements
    // ------------------------------------------------------------------------
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balances[_from] >= _value);
        //Check for empty transfer
        require(_value>0);
        // Check for overflows
        require(balances[_to].add(_value) > balances[_to]);
        // Check if sender is frozen
        require(!frozenAccount[_from]);
        // Check if reciever is frozen
        require(!frozenAccount[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balances[_from].add(balances[_to]);
        // Subtract from the sender
        balances[_from] = balances[_from].sub(_value);
        // Add the same to the recipient
        balances[_to] = balances[_to].add(_value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balances[_from].add(balances[_to]) == previousBalances);

        emit Transfer(_from, _to, _value);
    }


    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        _transfer(msg.sender,to,tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    //
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        require(tokens <= allowed[from][msg.sender]);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        _transfer(from,to,tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }


    // ------------------------------------------------------------------------
    // Creates new tokens and puts them in target´s account
    // ------------------------------------------------------------------------
    function mintToken(address target,uint amount) public onlyOwner returns(bool success){
      balances[target] = balances[target].add(amount);
      _totalSupply = _totalSupply.add(amount);
      emit Transfer(0, owner, amount);
      emit Transfer(owner, target, amount);
      return true;
    }

    // ------------------------------------------------------------------------
    // Burns tokens
    // ------------------------------------------------------------------------
    function burn(uint256 _value) public onlyOwner returns (bool success) {
    require(balances[msg.sender] >= _value);
    balances[msg.sender] = balances[msg.sender].sub(_value);
    _totalSupply = _totalSupply.sub(_value);
    emit Burn(msg.sender, _value);
    return true;
}


    // ------------------------------------------------------------------------
    // Freezes certain account. Tokens cannot be moved anymore
    // ------------------------------------------------------------------------
    function freezeAccount(address target, bool freeze) public onlyOwner returns(bool success){
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
        return true;
    }


    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
