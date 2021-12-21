pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./library/SafeERC20.sol";

import "./item.sol";

contract Exchange {

    using SafeMath for uint;

    using SafeERC20 for IERC20; 

    struct Order {
        uint id;
        uint itype;  // 1 package 2 item
        uint level;
        address orderMaker;
        address orderDeal;
        uint create_timestamp;
        uint stop_timestamp;
        uint order_type;  // 1 on sell   2 on buy
        uint status;   // 0 nothing   1 start  2 end  3 cancel
        uint price;
    }

    mapping(uint=>Order) public allOrder;

    uint public orderID = 10000;

    Item internal items;
    IERC20 public token;
    

    function setItems(address addr)public {
        items = Item(addr);
    }

    function setToken(address addr) public{
        token = IERC20(addr);
    }

    address public feeAddress ;

    uint public feeRate = 500;    //5%    500/10000

    event CreateOrder(address indexed maker,uint indexed id, uint indexed _type, uint timestamp);
    event CancelOrder(address indexed maker,uint indexed id, uint timestamp);
    event DealOrder(address indexed dealer, uint indexed id, uint timestamp);

    constructor(address feeAddr) public{
        feeAddress = feeAddr;
    }

    function makeOrder(uint _type,uint _itemId, uint _item_level,uint _price, uint _orderType) public{
        require(_price >= 0.1 ether, "price is too low");
        if(_orderType == 1){
            if(_type == 1){  // sell package
                Item.Pack memory p = items.getPackageInformation(_itemId);
                require(p.owner == msg.sender,"package is not yours");
                require(p.destroy_timestamp==0,"package has been destroied");
                items.transferFrom(msg.sender,address(this),_itemId,_type);
                allOrder[orderID].level = p.level;
            }else if(_type == 2){ // sell item
                Item.ItemInfo memory p = items.getItemInformation(_itemId);
                require(p.owner==msg.sender,"item is not yours");
                require(p.destroy_timestamp==0,"item has been destroied");
                require(p.durability == p.max_durability, "item need to be repaired");
                items.transferFrom(msg.sender,address(this),_itemId,_type);
                allOrder[orderID].level = p.level;
            }else{
                require(false,"error item type");
            }
            allOrder[orderID].itype = _type;
            allOrder[orderID].id = _itemId;
            allOrder[orderID].orderMaker = msg.sender;
            allOrder[orderID].create_timestamp = block.timestamp;
            allOrder[orderID].order_type = 1;
            allOrder[orderID].price = _price;
            allOrder[orderID].status = 1;      
            orderID = orderID.add(1);      
            emit CreateOrder(msg.sender, orderID-1, 1, block.timestamp);
        }else if (_orderType == 2){
            token.safeTransferFrom(msg.sender,address(this),_price); 
            allOrder[orderID].itype = _type;
            allOrder[orderID].orderMaker = msg.sender;
            allOrder[orderID].create_timestamp = block.timestamp;
            allOrder[orderID].level = _item_level;
            allOrder[orderID].order_type = 2;
            allOrder[orderID].price = _price;
            allOrder[orderID].status = 1;    
            orderID = orderID.add(1);     
             emit CreateOrder(msg.sender, orderID-1, 2, block.timestamp);   
        }
    }


    function cancelOrder(uint orderID)public{
        require(allOrder[orderID].orderMaker == msg.sender,"you are not order maker");
        require(allOrder[orderID].status == 1,"order was end or cancel");
        allOrder[orderID].status = 3;
        allOrder[orderID].stop_timestamp = block.timestamp;
        if(allOrder[orderID].order_type == 1){
            items.transfer(msg.sender,allOrder[orderID].id,allOrder[orderID].itype);
        }else if(allOrder[orderID].order_type==2){
            token.safeTransfer(msg.sender,allOrder[orderID].price);
        }
        emit CancelOrder(msg.sender,orderID,block.timestamp);
    }

    function buy(uint orderID, uint amount) public {
        require(allOrder[orderID].status == 1,"order was end or cancel");
        // require(allOrder[orderID].itype == 1,"order item type is wrong");
        require(allOrder[orderID].price <= amount,"price is too low");
        require(allOrder[orderID].order_type == 1,"order type is wrong"); 
        // need check  erc20 approval
        uint fee = amount.mul(feeRate).div(10000);
        uint balance = amount.sub(fee);
        token.safeTransferFrom(msg.sender,feeAddress,fee);
        token.safeTransferFrom(msg.sender,allOrder[orderID].orderMaker,balance);
        // token.transferFrom(msg.sender,feeAddress,fee);
        // token.transferFrom(msg.sender,allOrder[orderID].orderMaker,balance);
        items.transfer(msg.sender,allOrder[orderID].id,allOrder[orderID].itype);
        allOrder[orderID].status = 2;
        allOrder[orderID].orderDeal = msg.sender;
        allOrder[orderID].stop_timestamp = block.timestamp;
        emit DealOrder(msg.sender,orderID,block.timestamp);
    }

    function sell(uint orderID, uint item_id, uint itype) public {
        require(allOrder[orderID].status == 1,"order was end or cancel");
        // require(allOrder[orderID].itype == 2,"order type is wrong");
        require(allOrder[orderID].order_type == 2,"order type is wrong");
        require(itype == allOrder[orderID].itype,"order item type is wrong");
         // need check item approval 
        if(itype==1){
            Item.Pack memory p = items.getPackageInformation(item_id);
            require(p.owner == msg.sender,"pack is not yours");
            require(p.destroy_timestamp == 0 ,"pack has been destroied");
            require(p.level ==  allOrder[orderID].level,"not reach the pack level");
        }else if(itype == 2){
            Item.ItemInfo memory p = items.getItemInformation(item_id);
            require(p.owner == msg.sender, "item is not yours");
            require(p.destroy_timestamp == 0 ,"pack has been destroied");
            require(p.durability == p.max_durability, "item need to be repaired");
            require(p.level ==  allOrder[orderID].level,"not reach the item level");
        }
        
        uint fee = allOrder[orderID].price.mul(feeRate).div(10000);
        uint balance = allOrder[orderID].price.sub(fee);
        token.safeTransfer(feeAddress,fee);
        token.safeTransfer(msg.sender,balance);
        items.transferFrom(msg.sender,allOrder[orderID].orderMaker,item_id,itype);
        allOrder[orderID].status = 2;
        allOrder[orderID].orderDeal = msg.sender;
        allOrder[orderID].stop_timestamp = block.timestamp;
        allOrder[orderID].id = item_id;
        emit DealOrder(msg.sender,orderID,block.timestamp);

    }

}