//SPDX-License-Identifier: MIT

pragma solidity ^0.6.4;

//We could also import ownable contract from Open Zeppelin
contract Ownable {
    address payable _owner;

    constructor () public {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(isOwner(), "You are not the owner!");
        //This specifies when function needs to be executed 
        _;
    }

    function isOwner() public view returns(bool) {
        return (msg.sender == _owner);
    }
}

//Hand off payment to another smart contract
contract Item {
    uint public priceInWei;
    //Add in for success
    uint public pricePaid;
    uint public index;

    ItemManager parentContract;

    constructor(ItemManager _parentContract, uint _priceInWei, uint _index) public {
        priceInWei = _priceInWei;
        _index = _index;
        parentContract = _parentContract;
    }

    //Once item receive the money, boolean if succesful and other if return values
    receive() external payable {
        require(priceInWei == msg.value, "Only full payments are allowed.");
        require(pricePaid == 0, "Item is already paid.");
        //If prev require status goes through, then PricePaid should reflect that
        pricePaid += msg.value;
        //Not enough for transaction, so add in low-level function Call & specify data type
        (bool success, ) = address(parentContract).call{value:msg.value}(abi.encodeWithSignature("triggerPayment(uint256)", index));
        require(success, "Transaction was not succesful!.");
    }

    fallback() external {}

}

// Only this contract inherits Ownable contract
contract ItemManager is Ownable {

    enum SupplyChainState{Created, Paid, Delivered}

    struct S_Item {
        //Item added in for Contract Item to work
        Item _item;
        string _identifier;
        uint _itemPrice;
        ItemManager.SupplyChainState _state;
    }

    //This items mapping gives the structure and also links the itemss index to the identifier
    mapping(uint => S_Item) public items;
    uint itemIndex;

    //Added inb address to emit address item
    event SupplyChainStep(uint _itemIndex, uint _step, address _itemAddress);

    // onlyOwner is the only adress that can create an item
    function createItem(string memory _identifier, uint _priceInWei) public onlyOwner {
        Item item = new Item(this, _priceInWei, itemIndex);
        items[itemIndex]._item = item;
        items[itemIndex]._itemPrice = _priceInWei;
        //Import distinction is this itemIndex is the only one one without an underscore
        items[itemIndex]._identifier = _identifier;
        items[itemIndex]._state = SupplyChainState.Created;

        emit SupplyChainStep(itemIndex, uint(items[itemIndex]._state), address(item));
        itemIndex++;
    }

    function triggerPayment(uint _itemIndex) public payable {
        Item item =  items[_itemIndex]._item;
        require(address(item) == msg.sender, ":Only itmes are allowed tp update themselves!");
        require(item.priceInWei() == msg.value, "Only full payments are accepted");
        
        
        require(items[_itemIndex]._state == SupplyChainState.Created, "Item is further in the supply chain");

        items[_itemIndex]._state = SupplyChainState.Paid;        

        emit SupplyChainStep(_itemIndex, uint(items[_itemIndex]._state), address(items[_itemIndex]._item));
    }

    // onlyOwner is the only adress that can trigger a delivery
    function triggerDelivery(uint _itemIndex) public onlyOwner {
        require(items[_itemIndex]._state == SupplyChainState.Paid, "Item is not this far in the supply chain");

        items[_itemIndex]._state = SupplyChainState.Delivered;

        emit SupplyChainStep(_itemIndex, uint(items[_itemIndex]._state), address(items[_itemIndex]._item));
    }

}
