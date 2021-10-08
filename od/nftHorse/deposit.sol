// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ERC20 {
    function totalSupply() public view virtual returns (uint256);
    function balanceOf(address who) public view virtual returns (uint256);
    function transfer(address to, uint256 value) public virtual returns (bool);

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract Deposit is Ownable{
    ERC20 public fungibleContract;

    uint256 public erc20TokenValue;
    uint256 public depositLimit;
    address public erc20AdminAddress;
    mapping (address => uint256) public depositedValue;

    event DepositSuccess(address addr, uint256 value);

    constructor(){}

    function setERC20Address(address _address) external onlyOwner {
        fungibleContract = ERC20(_address);
    }

    function setERC20TokenValue(uint256 _wei) external onlyOwner {
        erc20TokenValue = _wei;
    }

    function setDepositLimit(uint256 _limit) public onlyOwner{
        depositLimit = _limit;
    }

    function setERC20AdminAddress(address _address) external onlyOwner {
        erc20AdminAddress = _address;
    }

    function deposit() public payable{
        require(msg.value%erc20TokenValue == 0, "not integer token");
        uint256 _value = msg.value/erc20TokenValue * (10**18);
        require((_value+depositedValue[msg.sender]) <= depositLimit, "out of erc20 limit");
        require(fungibleContract.transferFrom(erc20AdminAddress, msg.sender, _value), "transfer erc20 token failed");
        depositedValue[msg.sender]+=_value;
    }

    function withdrawBalance(address payable _address) external onlyOwner {
        uint256 balance = address(this).balance;
        _address.transfer(balance);
    }
}
