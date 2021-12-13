// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ERC20 {
    function totalSupply() public view virtual returns (uint256);
    function balanceOf(address who) public view virtual returns (uint256);
    function transfer(address to, uint256 value) public virtual returns (bool);

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract MultiSigWallet {
    address private owner;
    ERC20 public erc20Contract;
    mapping (address => bool) private managers;

    modifier onlyOwner{
        require(owner == msg.sender);
        _;
    }

    modifier isManager{
        require(
            msg.sender == owner || managers[msg.sender] == true);
        _;
    }

    uint constant MIN_SIGNATURES = 3;
    uint private txIds;

    struct Transaction {
        address from;
        address to;
        uint amount;
        uint8 signatureCount;
    }

    mapping ( uint => mapping( address => bool)) signatures;

    mapping (uint => Transaction) private transactions;
    uint[] private pendingTransactions;

    constructor() {
        owner = msg.sender;
    }

    event DepositFunds(address from, uint amount);
    event TransferFunds(address to, uint amount);
    event TransactionCreated(
        address from,
        address to,
        uint amount,
        uint transactionId
    );

    function addManager(address manager) public onlyOwner{
        managers[manager] = true;
    }

    function removeManager(address manager) public onlyOwner{
        delete managers[manager];
    }

    function setERC20ContractAddress(address _erc20) public onlyOwner{
        erc20Contract = ERC20(_erc20);
    }

    //    function () public payable{
    //        emit DepositFunds(msg.sender, msg.value);
    //    }

    //    function withdraw(uint amount) onlyOwner public{
    //        transferTo(msg.sender, amount);
    //    }

    function transferTo(address to,  uint amount) isManager public{
        //        require(address(this).balance >= amount);
        uint transactionId = txIds++;

        Transaction memory transaction = Transaction({
        from: msg.sender,
        to: to,
        amount: amount,
        signatureCount: 1
        });
        signatures[transactionId][msg.sender] = true;
        transactions[transactionId] = transaction;
        pendingTransactions.push(transactionId);
        emit TransactionCreated(msg.sender, to, amount, transactionId);
    }

    function getPendingTransactions() public isManager view returns(uint[] memory){
        return pendingTransactions;
    }

    function signTransaction(uint transactionId) public isManager{
        Transaction storage transaction = transactions[transactionId];
        require(address(0) != transaction.from, "invalid tx");
        // require(msg.sender != transaction.from);
        require(!signatures[transactionId][msg.sender], "has signed");
        signatures[transactionId][msg.sender] = true;
        transaction.signatureCount++;

        if(transaction.signatureCount >= MIN_SIGNATURES){
            require(address(this).balance >= transaction.amount);
            require(erc20Contract.transferFrom(address(this), transaction.to, transaction.amount), "erc20 transfer failed");
            emit TransferFunds(transaction.to, transaction.amount);
            deleteTransactions(transactionId);
        }
    }

    function deleteTransactions(uint transacionId) public isManager{
        bool replace = false;
        for(uint i = 0; i< pendingTransactions.length; i++){
            if (replace){
                pendingTransactions[i-1] = pendingTransactions[i];
            }else if(transacionId == pendingTransactions[i]){
                replace = true;
            }
        }
        require(replace, "invalid tx id");
        delete pendingTransactions[pendingTransactions.length - 1];
        delete transactions[transacionId];
        // delete signatures[transacionId];
    }

    function walletBalance() public isManager view returns(uint){
        return erc20Contract.balanceOf(address(this));
    }
}

