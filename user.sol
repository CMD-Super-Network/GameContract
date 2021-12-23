pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

// import "./items.sol";
import "./mine.sol";
import "./item.sol";
import "./monster.sol";

contract User {
    
    using SafeMath for uint;
    
    address private admin;
    
    struct UserInfo {
        string nickName;
        string head_url;
        // uint[] items;
        // uint[] packages;
        mapping(uint => uint[]) items2;
        mapping(uint => uint[]) packages2;
        mapping(uint => uint) fragmentInfo;
        bool status;
        uint timestamp;
        
        bytes32 action;
        
        
    }
    
    mapping(address => UserInfo) public users;
    mapping(bytes32 => bool) public nickNames;
    
    
    
    uint256 public CREATE_FEE = 2 ether;
    
    address public itemContract ;
    address public mineContract ;
    
    
    
    mapping (uint => uint) public TotalFragments;
    
    struct Reward {
        uint coin;
        uint itemid;
    }
    
    struct Action {
        uint action_time;
        uint a_id;
        uint action_type;
        uint status;    // 1 started   //2 end and collect reward    // 0 do nothing
        Reward reward;
    }
    
    mapping (bytes32 => Action) public allActions;
    
    address [] public allUser;
    bytes32 [] public actions;

    Item internal items;
    Mine internal mine;
    Monster internal monster;
    IERC20 internal token;
    
    address public governance ;
    // constructor (address _itemContract,address _mineContract) public {
    //     itemContract = _itemContract;
    //     mineContract = _mineContract;
    // }
    
    
    //----------------------------event
    event CreateUser(address indexed addr, uint indexed timestamp, string nickName);
    event UsedFragment(address indexed addr, uint indexed level, uint indexed amount, uint timestamp);
    event PackFragment(address indexed addr, uint indexed packId, uint indexed level, uint timestamp);
    event UpackedFragment(address indexed addr, uint indexed level, uint indexed packId, uint timestamp);
    event IncreaseFragment(address indexed addr, uint indexed level, uint indexed amount, uint timestamp);
    event DecreaseFragment(address indexed addr, uint indexed level, uint indexed amount, uint timestamp);
    event StartAction(address indexed addr, bytes32 indexed action, uint indexed action_type, uint a_id, uint timestamp);
    event ChangeNickName(address indexed addr, uint indexed timestamp, string nickName);
    event ChangeHeadUrl(address indexed addr, uint indexed timestamp, string headurl);
    event UpgradeItemFailed(address indexed addr, uint indexed level, uint timestamp);
    //----------------------------end event
    
    struct UserAction {
        bool status;
        uint actionid;
        uint action_type;
    }

    mapping(address =>UserAction) userAction;

    constructor()public{
        governance = msg.sender;
    }

    modifier onlyOwner(){
        require(governance == msg.sender,"not owner");
        _;
    }

    function setItem(address addr) public onlyOwner {
        items = Item(addr);
    }

    function setMine(address addr) public onlyOwner{
        mine = Mine(addr);
    }

    function setMonster(address addr) public onlyOwner{
        monster = Monster(addr);
    }

    function changeOwner(address addr) public onlyOwner{
        governance = addr;
    }

    function setToken(address addr)public onlyOwner {
        token = IERC20(addr);
    }


    
    function createUser(string memory nickName, string memory head_url) payable public returns(bool) {
        require(users[msg.sender].status == false,"user already exists");
        // uint256 value  = msg.value;
        // require(value == CREATE_FEE,"need 2 CMD to create user");
        bytes32 id ;
        assembly{
            id := mload(add(nickName,32))
        }
        require(nickNames[id]==false,"nickName already exists");
        users[msg.sender].nickName = nickName;
        users[msg.sender].head_url = head_url;
        users[msg.sender].status = true;
        
        uint itemId = items.createItem(msg.sender,1);
        
        users[msg.sender].items2[1].push(itemId);
        users[msg.sender].timestamp = block.timestamp;
        
        allUser.push(msg.sender);
       
        nickNames[id]= true;
        emit CreateUser(msg.sender, block.timestamp, nickName);
        
        return true;        
    }

    function defaultCreate(address addr) internal returns(bool){
        users[addr].nickName = "";
        users[addr].head_url = "";
        users[addr].status = true;
        users[addr].timestamp = block.timestamp;
    }
    
    
    function changeNickName(string memory nickName)public returns (bool){
        require(users[msg.sender].status == true,"user is not exists");
        bytes32 id;
        assembly{
            id := mload(add(nickName,32))
        }
        require(nickNames[id]==false,"nickName already exists");
        string memory a = users[msg.sender].nickName;
        bytes32 id2;
        assembly{
            id2 := mload(add(a,32))
        }
        nickNames[id2]= false;
        nickNames[id] = true;
        users[msg.sender].nickName = nickName;
        emit ChangeNickName(msg.sender,block.timestamp, nickName);
        return true;
    }


    function changeHeadUrl(string memory url) public returns (bool){
        require(users[msg.sender].status == true,"user is not exists");
        users[msg.sender].head_url = url;
        emit ChangeHeadUrl(msg.sender,block.timestamp,url);
    }


    function action(uint actionType, bytes32 id, uint itemid) public returns (uint){
        require(userAction[msg.sender].status==false,"user has action, please finish this user action");
        Item.ItemInfo memory info = items.getItemInformation(itemid);
        require(info.owner == msg.sender,"not yours");
        require(info.durability >0 ,"item was broken"); 
        items.decreaseItemDurability(msg.sender, itemid);
        userAction[msg.sender].status = true;
        userAction[msg.sender].action_type = actionType;
        if(actionType == 1){ // mine
            uint mid = mine.mine(msg.sender, id, itemid);
            userAction[msg.sender].actionid = mid;
        }else if (actionType == 2) {  // hunter
            uint mid = monster.fightMonster(msg.sender, id);
            userAction[msg.sender].actionid = mid;
        }
    }

    function finishAction()public{
        require(userAction[msg.sender].status == true," user action has been finished");
        if(userAction[msg.sender].action_type == 1){
            Mine.RewardRes memory res = mine.collectMineReward(msg.sender,userAction[msg.sender].actionid);
            if(res.status == true){
                increaseFragments(res.level,res.amount);
            }
        }else if(userAction[msg.sender].action_type == 2){
            Monster.RewardRes memory res = monster.collectMonsterReward(msg.sender, userAction[msg.sender].actionid);
            token.mint(msg.sender, res.tokenAmount);
            if (res.level >0){
                items.createItem(msg.sender,res.level);
            }
        }
    }
    
    
    function increaseFragments(uint _type, uint amount) public returns (bool){
        require(users[msg.sender].status,"user not exists");
        users[msg.sender].fragmentInfo[_type] = users[msg.sender].fragmentInfo[_type].add(amount);
        TotalFragments[_type] = TotalFragments[_type].add(amount);
        return true;
    }
    
    // // pack fragment
    function userPackageFramgent(uint _type) public returns(uint){
        require(users[msg.sender].status,"user not exists");
        require(users[msg.sender].fragmentInfo[_type]>=100,"this type for frament need over 100 pcs for package");
        users[msg.sender].fragmentInfo[_type] = users[msg.sender].fragmentInfo[_type].sub(100);
        uint id = items.packFragment(msg.sender, _type);
        users[msg.sender].packages2[_type].push(id);
        emit PackFragment(msg.sender, id, _type,block.timestamp);
        return id;
        
    }
    
    // // unpack fragment
    function userUnpackFragment(uint id)public returns(bool){
        Item.Pack memory p = items.getPackageInformation(id);
        require(p.owner == msg.sender,"your are not owner");
        require(p.destroy_timestamp ==0,"it has been destoried");
        bool f = items.unpackFragemt(msg.sender,id);
        if(f){
            deletePackageArray(p.level,id,msg.sender);
            users[msg.sender].fragmentInfo[p.level] = users[msg.sender].fragmentInfo[p.level].add(100);
            emit UpackedFragment(msg.sender,p.level,id,block.timestamp);
            return true;
        }else{
            return false;
        }
    }
    
    // // 777 fragment to item
    function fragmentToItem(uint level) public returns(uint){
        require(users[msg.sender].status,"user not exists");
        require(users[msg.sender].fragmentInfo[level] >=777,"not enought fragments");
        users[msg.sender].fragmentInfo[level] = users[msg.sender].fragmentInfo[level].sub(777);
        emit DecreaseFragment(msg.sender,level,777,block.timestamp);
        uint id = items.createItem(msg.sender, level);
        users[msg.sender].items2[level].push(id);
        return id;
    }

    function upgradeItemLevel(uint item1, uint item2, uint item3) public returns (uint){
        bool f = items.upgradeItem(msg.sender, item1, item2, item3);

        Item.ItemInfo memory p1 = items.getItemInformation(item1);
        if(f){
            _destroyItemWithEvent(item1,msg.sender);
            _destroyItemWithEvent(item2,msg.sender);
            _destroyItemWithEvent(item3,msg.sender);
            uint id = items.createItem(msg.sender,p1.level+1);
            users[msg.sender].items2[p1.level+1].push(id);
            return id;
        }else{

            emit UpgradeItemFailed(msg.sender,p1.level,block.timestamp);

            _destroyItemWithEvent(item3,msg.sender);
            increaseFragments(p1.level,600);
            emit IncreaseFragment(msg.sender,p1.level,600,block.timestamp);
            
        }
        return 0;
    }
    
    function _destroyItemWithEvent(uint item, address addr) internal {
        _destroyItem(item,addr);
        // emit DestroyItem(addr, item, items[item].level, block.timestamp);
    }

    function _destroyItem(uint item, address addr) internal {
        // items[item].destroy_timestamp = block.timestamp;
        items.destoryItem(addr, item);
        Item.ItemInfo memory p1 = items.getItemInformation(item);
        deleteItemsArray(p1.level,item,addr);
    }

    function _destroyPackageWithEvent(uint pid, address addr) internal {
        _destroyPackage(pid, addr);
        // emit DestroyPackage(addr,pid,packages[pid].level, block.timestamp);
    }

    function _destroyPackage(uint pid, address addr) internal {
        Item.Pack memory packInfo = items.getPackageInformation(pid);
        // packages[pid].destroy_timestamp = block.timestamp;
        items.destoryPackage(addr,pid);
        deletePackageArray(packInfo.level, pid, addr);
    } 

    
    function reqaireItem(uint itemid, uint packid ) public {
        items.repaireItem(msg.sender,itemid,packid);
        _destroyPackageWithEvent(packid, msg.sender);
        // emit RepaireItem(msg.sender,itemid, packid, c, block.timestamp);

    }

    // function UserCollectMineReward(uint id) public returns(bool){
    //     RewardRes memory res = collectMineReward(id);
    //     if(res.status){
    //         increaseFragments(res.level,res.amount);
    //         return true;
    //     }else{
    //         return false;
    //     }
    // }
    
    function deletePackageArray(uint level,uint id, address orginal_addr) internal {
        bool flag = false;
         for (uint i = 0; i<users[orginal_addr].packages2[level].length; i++){
            if(users[orginal_addr].packages2[level][i] == id){
                if (i == users[orginal_addr].packages2[level].length-1){
                    flag = true;
                    break;
                }else{
                    users[orginal_addr].packages2[level][i] = users[orginal_addr].packages2[level][users[orginal_addr].packages2[level].length-1];
                    flag = true;
                    break;
                }
            }
        }
        if (flag){
            delete users[orginal_addr].packages2[level][users[orginal_addr].packages2[level].length-1];
            users[orginal_addr].packages2[level].length--;
        }
    }

    function deleteItemsArray(uint level,uint id, address orginal_addr) internal {
        bool flag = false;
         for (uint i = 0; i<users[orginal_addr].items2[level].length; i++){
            if(users[orginal_addr].items2[level][i] == id){
                if (i == users[orginal_addr].items2[level].length-1){
                    flag = true;
                    break;
                }else{
                    users[orginal_addr].items2[level][i] = users[orginal_addr].items2[level][users[orginal_addr].items2[level].length-1];
                    flag = true;
                    break;
                }
            }
        }
        if (flag){
            delete users[orginal_addr].items2[level][users[orginal_addr].items2[level].length-1];
            users[orginal_addr].items2[level].length--;
        }
    }
    

    function randonmNumber(bytes32 id) internal view returns(uint){
        return uint(keccak256(abi.encodePacked(msg.sender,msg.sender,id,block.timestamp)))%10000;
    }

    // //-------------------------------------------------get user information
    
    function getUserItems(uint level) public view returns(uint [] memory){
        return users[msg.sender].items2[level];
    }
    
    function getUserFragment(uint _type) public view returns(uint){
        return users[msg.sender].fragmentInfo[_type];
    }
    
    function getUserPackages(uint level) public view returns (uint[]memory){
        return users[msg.sender].packages2[level];
    }
    
    function checkUserItems(address addr,uint level) public view returns( uint [] memory ){
        return users[addr].items2[level];
    }
    
    function checkUserPackages(address addr,uint level) public view returns(uint[]memory){
        return users[addr].packages2[level];
    }
    
    function checkUserFragment(address addr, uint _type) public view returns(uint){
        return users[addr].fragmentInfo[_type];
    }

    // //-------------------------------------------------end
    

    // //-------------------------------------------------get all information
    function getAllUser()public view returns(address[]memory){
        return allUser;
    }
    // //-------------------------------------------------end
    
    
    
    // function withdrawCreateFee(uint256 amount)public payable{
    //     require(msg.sender == admin,"no permmit");
    //     msg.sender.transfer(amount);
    // }


    // //---------------- 721 user
    // function transfer (address _to, uint _tokenID, uint _type) public returns (bool){
    //     // require(users[_to].status == true, "user is not exists");
    //     if(users[_to].status==false){
    //         defaultCreate(_to);
    //     }
    //     address orignal_owner;
    //     if(_type==1){
    //         require(packages[_tokenID].destroy_timestamp == 0,"package has been destoried");
    //         orignal_owner = packages[_tokenID].owner;
    //     }else if(_type==2){
    //         require(items[_tokenID].destroy_timestamp == 0, "item has been destoried");
    //         orignal_owner = items[_tokenID].owner;
    //     }
    //     bool f = _transfer(_to,_tokenID,_type);
    //     if(f){
    //         if(_type==1){
    //             deletePackageArray(packages[_tokenID].level,_tokenID,msg.sender);
    //             users[_to].packages2[packages[_tokenID].level].push(_tokenID);
    //         }else if(_type==2){
    //             deleteItemsArray(items[_tokenID].level,_tokenID,msg.sender);
    //             users[_to].items2[items[_tokenID].level].push(_tokenID);
    //         }
    //         return true;
    //     }
    //     return false;
    // }

    // function transferFrom(address _from, address _to, uint _tokenId, uint _type)public returns(bool){
    //     if(users[_to].status == false){
    //         defaultCreate(_to);
    //     }
    //     address orignal_owner;
    //     if(_type==1){
    //         require(packages[_tokenId].destroy_timestamp == 0,"package has been destoried");
    //         orignal_owner = packages[_tokenId].owner;
    //     }else if(_type==2){
    //         require(items[_tokenId].destroy_timestamp == 0, "item has been destoried");
    //         orignal_owner = items[_tokenId].owner;
    //     }
    //     bool f = _transferFrom(_from, _to, _tokenId, _type);
    //     if(f){
    //         if(_type==1){
    //             deletePackageArray(packages[_tokenId].level,_tokenId,orignal_owner);
    //             users[_to].packages2[packages[_tokenId].level].push(_tokenId);
    //         }else if(_type==2){
    //             deleteItemsArray(items[_tokenId].level,_tokenId,orignal_owner);
    //             users[_to].items2[items[_tokenId].level].push(_tokenId);
    //         }
    //         return true;
    //     }
    //     return false;
    // }



    // function approve(address _to, uint _tokenId, uint _type)public{
    //     _approve(_to,_tokenId,_type);
    // }
    
}