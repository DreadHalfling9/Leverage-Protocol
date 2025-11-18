// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event Confirm(address indexed owner, uint256 indexed txIndex);
    event Revoke(address indexed owner, uint256 indexed txIndex);
    event Execute(uint256 indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required confirmations");

        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Zero address");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint256 _value, bytes calldata _data) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, numConfirmations: 0}));

        emit Submit(txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        confirmations[_txIndex][msg.sender] = true;
        transactions[_txIndex].numConfirmations += 1;

        emit Confirm(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage txn = transactions[_txIndex];
        require(txn.numConfirmations >= required, "Not enough confirmations");

        txn.executed = true;

        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Tx failed");

        emit Execute(_txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(confirmations[_txIndex][msg.sender], "Tx not confirmed");

        confirmations[_txIndex][msg.sender] = false;
        transactions[_txIndex].numConfirmations -= 1;

        emit Revoke(msg.sender, _txIndex);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        external
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations)
    {
        Transaction memory txn = transactions[_txIndex];
        return (txn.to, txn.value, txn.data, txn.executed, txn.numConfirmations);
    }
}
