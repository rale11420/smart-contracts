// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title MultiSigWallet example
contract MultiSigWallet {

    //events    
    event Deposit(address indexed donor, uint amount);
    event CreateTransaction(uint id, address indexed caller, address indexed to, uint amount);
    event ApproveTransaction(uint indexed id, address indexed owner);
    event CancelApproval(uint indexed id, address indexed owner);
    event ExecuteTransaction(uint id, address indexed to, uint amount);
    event AddOwner(address indexed newOwner);
    event RemoveOwner(address indexed exOwner);

    //modifiers
    modifier onlyOwners {
        require(isOwner[msg.sender] == true, "Not owner");
        _;
    }

    modifier ValidID(uint id) {
        require(id >= 0 && id <= transactions.length, "Invalid ID");
        _;
    }

    modifier NotExecuted(uint id) {
        require(transactions[id].status == false, "Already executed");
        _;
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    struct Transaction {
        address to;
        uint amount;
        uint numberOfConformations;
        bool status;
    }

    address owner;
    address[] public owners;
    Transaction[] public transactions;
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public approvals;

    /// @notice Adding owners in array
    /// @param _owners is array of all the owners of wallet
    constructor(address[] memory _owners) {
        require(_owners.length > 0, "No owners in array");
        owner = msg.sender;
        owners.push(owner);
        isOwner[owner] = true;
        for(uint i = 1; i <= _owners.length; i++) {
            address temp = _owners[i-1];
            require(temp != address(0), "Owner can't be address 0");
            require(isOwner[temp] == false, "Already owner");
            isOwner[temp] = true;

            owners.push(temp);
        }
    }
    
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Creating new transaction
    /// @param _to is address where msg.sender wants to send ETH
    /// @param _amount is amount of ETH
    function Create(address _to, uint _amount) external onlyOwners {
        require(_to != address(0), "Transaction can't be sent to address 0");
        require(_amount > 0, "Amount must be greater then 0");

        transactions.push(Transaction(_to, _amount, 0, false));

        emit CreateTransaction(transactions.length, msg.sender, _to, _amount);
    }

    /// @notice Function is used by the owners to approve transactions
    /// @param _id is id of transaction in trasaction array
    function Approve(uint _id) external onlyOwners ValidID(_id) NotExecuted(_id) {
        require(approvals[_id][msg.sender] == false, "Already approved");
        approvals[_id][msg.sender] = true;
        transactions[_id].numberOfConformations += 1;

        emit ApproveTransaction(_id, msg.sender);
    }

    /// @notice Function is used by the owners to cancel already approved transactions 
    /// @param _id is id of transaction in trasaction array
    function Cancel(uint _id) external onlyOwners ValidID(_id) NotExecuted(_id) {
        require(approvals[_id][msg.sender] == true, "Not approved");
        approvals[_id][msg.sender] = false;
        transactions[_id].numberOfConformations -= 1;

        emit CancelApproval(_id, msg.sender);
    } 

    /// @notice Function is used by the owners to execute already approved transactions 
    /// @notice Amount of votes needed is 2/3 of all owners count
    /// @param _id is id of transaction in trasaction array
    function Execute(uint _id) external onlyOwners ValidID(_id) NotExecuted(_id) {
        Transaction storage temp = transactions[_id];
        require((3*temp.numberOfConformations) >= (2*owners.length), "Not enough approvals");
        require(address(this).balance > temp.amount, "Not enough funds");
        temp.status = true;

        payable(temp.to).transfer(temp.amount);

        emit ExecuteTransaction(_id, temp.to, temp.amount);
    }   

    /// @notice Function is used by owner (deployer)
    /// @param _newOwner is address of owner who will be added
    function add(address _newOwner) external onlyOwner {
        require(_newOwner != address(0),"Owner can't be address 0");
        require(isOwner[_newOwner] == false,"Already owner");

        owners.push(_newOwner);
        isOwner[_newOwner] = true;

        emit AddOwner(_newOwner);
    } 
    
    /// @notice Function is used by owner (deployer)
    /// @param _exOwner is address of owner who will be removed
    function remove(address _exOwner) external onlyOwner {
        require(_exOwner != address(0),"Owner can't be address 0");
        require(owner != _exOwner,"Owner can't be removed from owners");
        require(isOwner[_exOwner] == true, "Not owner");

        isOwner[_exOwner] = false;

        for (uint i=0; i<owners.length - 1; i++) {
            if (owners[i] == _exOwner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();

        emit RemoveOwner(_exOwner);
    } 

    //get
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

}
