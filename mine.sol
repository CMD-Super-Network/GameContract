pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./library/SafeERC20.sol";
import "./item.sol";


contract Mine {
    
    using SafeMath for uint;    
    
    using SafeERC20 for IERC20; 

    struct RentDetail{
        address rentBy;
        uint rent_startTime;
        uint rent_time;

    }
    
    struct MineInfo {
        uint capacity;
        uint balance;
        uint level;
        address owner;
        address creator;
        uint create_timestamp;
        uint status; //0  nothing 1 run forever  2 searching  3 can rent 4 finish
        uint searchFee;
        uint rent;
        RentDetail r;
        bool rent_status;
        uint recordId;
    }
    
    struct MineRecord {
        bytes32 mineId;
        uint start_timestamp; 
        uint end_timestamp;
        uint level;
        uint fragmentlevel;
        uint amount;
        uint itemId;
        uint itemLevel;
        address miner;
    }
    
    struct MineType{
        uint min_range;
        uint max_range;
        uint searchFee;
        uint minttime;
        bool status;
        uint[] range;
    }
    
    mapping(bytes32 => MineInfo) public allMines;
    mapping(uint => MineType) public allTypes;
    
    bytes32[] public mines;
    
    uint public tax = 0;
    
    uint public mineIndex = 1;
    
    mapping(uint=>MineRecord) public allMineRecords;
    
    
    // address ERC20Contract = 0x54D62E3721694ebA0643d31CF1E7142B8c64554E;
    address SystemAddress = 0x70f7a852965c1EF0D99e2324F7F7f4eC891e1279;

     
    address ItemAddress = address(0);

    address userAddress = address(0);

    address governance;
    
    IERC20 public token;
    // ItemInterface public itemInterface;
    
    Item public items;
    
    uint public totalMine = 0;


    uint public searchFee = 1 ether;
    
    mapping(address => bool) public onSearchUser;
    
    event SearchMineStartE(address indexed search, bytes32 indexed id, uint indexed timestamp);
    event CollectMineE(address indexed search, bytes32 indexed id, uint indexed level, uint timestamp);
    event RentMineE(address indexed ret,uint indexed id, bytes32 indexed mine_id, uint timestamp);
    event CollectMineRewardE(address indexed ret, uint indexed id, uint indexed timestamp);

    
    constructor()public{
        governance = msg.sender;

        bytes32 id = bytes32(0);
        allMines[id].capacity = 0;
        allMines[id].balance = 0;
        allMines[id].level = 0;
        allMines[id].owner = address(0);
        allMines[id].create_timestamp = block.timestamp;
        allMines[id].status = 1;
        allMines[id].searchFee = 0;
        allMines[id].rent = 0;
        mines.push(id);
        totalMine = totalMine.add(1);
        
        allTypes[1].min_range = 120;
        allTypes[1].max_range = 168;
        allTypes[1].searchFee = 1 ether;
        allTypes[1].minttime = 50 minutes;
        allTypes[1].status = true;
        allTypes[1].range = [8000,9000,9400,9700,9900];
        
        allTypes[2].min_range = 120;
        allTypes[2].max_range = 168;
        allTypes[2].searchFee = 2 ether;
        allTypes[2].minttime = 40 minutes;
        allTypes[2].range = [6000,9000,9400,9700,9900];
        allTypes[2].status = true;
        
        allTypes[3].min_range = 120;
        allTypes[3].max_range = 168;
        allTypes[3].searchFee = 3 ether;
        allTypes[3].minttime = 30 minutes;
        allTypes[3].range = [5000,8000,9400,9700,9900];
        allTypes[3].status = true;
        
        
        allTypes[4].min_range = 120;
        allTypes[4].max_range = 168;
        allTypes[4].searchFee = 4 ether;
        allTypes[4].minttime = 20 minutes;
        allTypes[4].range =[4000,7000,8400,9700,9900];
        allTypes[4].status = true;
        
        
        allTypes[5].min_range = 120;
        allTypes[5].max_range = 168;
        allTypes[5].searchFee = 5 ether;
        allTypes[5].minttime = 10 minutes;
        allTypes[5].range = [3000,6000,7900,9200,9900];
        allTypes[5].status = true;
        
        
        allTypes[6].min_range = 120;
        allTypes[6].max_range = 168;
        allTypes[6].searchFee = 6 ether;
        allTypes[6].minttime = 5 minutes;
        allTypes[6].range = [2000,5000,6900,8200,9400];
        allTypes[6].status = true;
        
    }

    modifier onlyOwner() {
        require(governance == msg.sender,"you are not owner");
        _;
    }

    modifier onlyUserAddr(){
        require(userAddress == msg.sender,"only user contract address");
        _;
    }
    
    function addTotalMines(uint amount) public {
        totalMine = totalMine.add(amount);
    }
    
    function startMine(bytes32 mine_id) internal {
        
    }
    
    function setToken(address addr)public{
        token = IERC20(addr);
    }
    
    function setItem(address addr) public {
        items = Item(addr);
    }

    function setUserAddress(address addr) public onlyOwner{
        userAddress = addr;
    }
    


    function searchMine(address user, uint amount) public onlyUserAddr returns (bytes32){
        require(onSearchUser[user] == false,"your are searching mine, please collect mine!");
        require(amount<=token.allowance(msg.sender,address(this)) , "not enough approval");
        require(totalMine > mines.length ,"reach limit mines");
        require(amount>=searchFee,"please transfer more token to start search mine");
        token.safeTransferFrom(msg.sender,SystemAddress,amount);
        bytes32 id = keccak256(abi.encodePacked(msg.sender,msg.sender,"2",block.timestamp));
        allMines[id].capacity = 0;
        allMines[id].balance = 0;
        allMines[id].level = 0;
        allMines[id].owner = user;
        allMines[id].creator = user;
        allMines[id].create_timestamp = block.timestamp;
        allMines[id].status = 2;
        allMines[id].searchFee = amount;
        allMines[id].rent = 0;
        mines.push(id);
        onSearchUser[user] = true;
        emit SearchMineStartE(user,id,block.timestamp);
        return id;
    }

    function collectMine(address user, bytes32 mine_id) public onlyUserAddr returns (MineInfo memory){
        require(mine_id != bytes32(0),"can't collect default mine");
        require(allMines[mine_id].owner == user, "not your mine");
        require(allMines[mine_id].status == 2 , "this mine had been found");
        uint capacity = randomCapacity(user);
        uint r = randonmNumber(user,mine_id);
        uint level = 1;
        if(allMines[mine_id].searchFee >= allTypes[1].searchFee && allMines[mine_id].searchFee <allTypes[2].searchFee){
            level = getLevel(r,1);
        }else if(allMines[mine_id].searchFee >= allTypes[2].searchFee && allMines[mine_id].searchFee <allTypes[3].searchFee){
            level = getLevel(r,2);
        }else if(allMines[mine_id].searchFee >= allTypes[3].searchFee && allMines[mine_id].searchFee <allTypes[4].searchFee){
            level = getLevel(r,3);
        }else if(allMines[mine_id].searchFee >= allTypes[4].searchFee && allMines[mine_id].searchFee <allTypes[5].searchFee){
            level = getLevel(r,4);
        }else if(allMines[mine_id].searchFee >= allTypes[5].searchFee && allMines[mine_id].searchFee <allTypes[6].searchFee){
            level = getLevel(r,5);
        }else if(allMines[mine_id].searchFee >= allTypes[6].searchFee){
            level = getLevel(r,6);
        }
        allMines[mine_id].level = level;
        allMines[mine_id].capacity = capacity;
        allMines[mine_id].balance = capacity;
        allMines[mine_id].status = 3;
        onSearchUser[user] = false;
        emit CollectMineE(user,mine_id,level,block.timestamp);
        return allMines[mine_id];
    }
    
    function randomCapacity(address user) internal view returns (uint) {
        uint random = uint(keccak256(abi.encodePacked(user,user,"2",block.timestamp)));
        return  random%48+120;
    }
    
    function randonmNumber(address user, bytes32 id) internal view returns(uint){
        return uint(keccak256(abi.encodePacked(user,user,id,block.timestamp)))%10000;
    }
    
    function getLevel(uint number, uint level)internal view returns(uint){
       if(number >= allTypes[level].range[4]){
           return 6;
       }else if(number >=allTypes[level].range[3]){
           return 5;
       }else if(number >=allTypes[level].range[2]){
           return 4;
       }else if(number >=allTypes[level].range[1]){
           return 3;
       }else if(number >=allTypes[level].range[0]){
           return 2;
       }else {
           return 1;
       }
    }
    
    
    // need sub item duration
    // function rentMine(bytes32 mine_id,uint amount, uint item_id) public returns (uint) {
    //     require(allMines[mine_id].status == 3 || allMines[mine_id].status == 1,"mine is not ready!");
    //     if(mine_id != bytes32(0)){
    //         require(allMines[mine_id].balance>0,"mine is empty");
    //         require(amount>=allMines[mine_id].rent,"not reach mine rent");
    //     }
    //     ItemInfo memory info = getItems(item_id);
    //     require(info.owner == msg.sender , "item not yours");
    //     require(info.durability>0,"item durability is over, please repaire it");
    //     // bytes32 id = keccak256(abi.encodePacked(allMines[mine_id].owner,msg.sender,mine_id,block.timestamp));
    //     if(mine_id != bytes32(0)){
    //         allMines[mine_id].balance = allMines[mine_id].balance.sub(1);
    //     }
    //     if(items[item_id].durability>0){
    //         items[item_id].durability = items[item_id].durability.sub(1);
        
    //         uint id = mineIndex;
    //         allMineRecords[mineIndex].mineId = mine_id;
    //         allMineRecords[mineIndex].start_timestamp = block.timestamp;
    //         allMineRecords[mineIndex].level = allMines[mine_id].level;
    //         allMineRecords[mineIndex].miner = msg.sender;
    //         allMineRecords[mineIndex].itemId = item_id;
    //         allMineRecords[mineIndex].itemLevel = info.level;
    //         mineIndex = mineIndex.add(1);
    //         emit RentMineE(msg.sender,id,mine_id,block.timestamp);
    //         return id;
    //     }else{
    //         return 0;
    //     }
    // }

    function rentMine2(address user, bytes32 mine_id,uint amount)public onlyUserAddr returns (bool){
        if(mine_id != bytes32(0)){
            require(allMines[mine_id].balance>0,"mine is empty");
            require(amount>=allMines[mine_id].rent,"not reach mine rent");
            require(allMines[mine_id].owner != user,"can't rent your own mine");
        }else{
            require(false,"default mine can't rent");
        }
        if(allMines[mine_id].rent_status){
            // check time it's up
            // if(allMines[mine_id].r.rent_startTime + allMines[mine_id].r.rent_time <= block.timestamp){
            //     // rent tin false;me is finish
            //     // RewardRes memory res =  caculatorReward(allMines[mine_id].recordId,allMines[mine_id].r.rentBy);
            //     require(false,"")
            //     retur
            // }else{
                require(false,"can't rent, other miner is working");
            // }
        }else{
            require(allMines[mine_id].r.rent_time == 0,"not for rent");
            token.safeTransferFrom(msg.sender,allMines[mine_id].owner,amount);
            allMines[mine_id].rent_status = true;
            allMines[mine_id].r.rentBy = user; 
            allMines[mine_id].r.rent_startTime = block.timestamp;
            return true;
        }
        return false;
    }
    
    function setRent2(address user, bytes32 mine_id, uint amount, uint time) public onlyUserAddr returns (RewardRes memory) {
        require(allMines[mine_id].owner == user,"not yours");
        require(time >= 1 hours && time <= 7 days,"time need in range 1 hours to 7 days");
        if(allMines[mine_id].rent_status){
            // check time it's up
            if(allMines[mine_id].r.rent_startTime + allMines[mine_id].r.rent_time <= block.timestamp){
                // rent time is finish
                RewardRes memory res =  caculatorReward(allMines[mine_id].recordId,allMines[mine_id].r.rentBy);
                return res;
            }else{
                require(false,"can't set rent, other miner is working");
            }
        }else{
            allMines[mine_id].rent = amount;
            allMines[mine_id].r.rent_time = time;
        }
        RewardRes memory res;
        return res;
    }


    function mine(address user, bytes32 mine_id,uint item_id)public onlyUserAddr returns (uint){
        require(allMines[mine_id].status == 3 || allMines[mine_id].status == 1,"mine is not ready!");
        if(mine_id != bytes32(0)){
            require(allMines[mine_id].balance>0,"mine is empty");
            // require(amount>=allMines[mine_id].rent,"not reach mine rent");
            require(allMines[mine_id].r.rentBy == msg.sender,"you did not rent this mine");
        }
        
        Item.ItemInfo memory info = items.getItemInformation(item_id);
        require(info.owner == msg.sender , "item not yours");
        require(info.durability>0,"item durability is over, please repaire it");
        // bytes32 id = keccak256(abi.encodePacked(allMines[mine_id].owner,msg.sender,mine_id,block.timestamp));
        if(mine_id != bytes32(0)){
            allMines[mine_id].balance = allMines[mine_id].balance.sub(1);
        }
        if(info.durability>0){
            // items[item_id].durability = items[item_id].durability.sub(1);
            // need sub durability from user contract
        
            uint id = mineIndex;
            allMineRecords[mineIndex].mineId = mine_id;
            allMineRecords[mineIndex].start_timestamp = block.timestamp;
            allMineRecords[mineIndex].level = allMines[mine_id].level;
            allMineRecords[mineIndex].miner = user;
            allMineRecords[mineIndex].itemId = item_id;
            allMineRecords[mineIndex].itemLevel = info.level;
            mineIndex = mineIndex.add(1);
            emit RentMineE(msg.sender,id,mine_id,block.timestamp);
            return id;
        }else{
            return 0;
        }

    }

    //re-calcualtor reward
    function caculatorReward(uint id, address addr)internal returns (RewardRes memory){
        uint time ;
        if(allMineRecords[id].mineId==bytes32(0)){
            time = 60 minutes;
        }else{
            time  = allTypes[allMineRecords[id].level].minttime;
        }
        require(allMineRecords[id].start_timestamp+time <= block.timestamp,"not reach the time to collect reward");
        Item.ItemInfo memory info = items.getItemInformation(allMineRecords[id].itemId);
        RewardRes memory res;
        if(info.owner == msg.sender && info.durability > 0){
        // check item id
            uint r = randonmNumber(addr, allMineRecords[id].mineId);
            uint n = 1;
            if (r>9900){
                n = 2;
            }
            allMineRecords[id].amount = n;
            if(allMineRecords[id].itemLevel == 1){
                allMineRecords[id].fragmentlevel = 1;
            }else if(allMineRecords[id].itemLevel == 2){
                allMineRecords[id].fragmentlevel = getFragmentLevel(addr, 2);
            }else if(allMineRecords[id].itemLevel >=3 && allMineRecords[id].itemLevel <=6){ 
                allMineRecords[id].fragmentlevel = getFragmentLevel(addr, allMineRecords[id].itemLevel);
            }
            // allMines[allMineRecords[id].mineId].balance = allMines[allMineRecords[id].mineId].balance.sub(1);
            allMineRecords[id].end_timestamp = block.timestamp;
            emit CollectMineRewardE(addr,id,block.timestamp);
            res.status = true;
            res.level =  allMineRecords[id].fragmentlevel;
            res.amount =  n;
            return res;
        }else{
            allMineRecords[id].end_timestamp = block.timestamp;
            return res;
        }

    }

    struct RewardRes{
        bool status;
        uint level;
        uint amount;
    }
    
    function collectMineReward(address user, uint id) internal returns (RewardRes memory){
        require(allMineRecords[id].end_timestamp == 0, "already collected reward");
        require(allMineRecords[id].miner == msg.sender,"not yours");
        return caculatorReward(id,msg.sender);
    }
    
    function getFragmentLevel(address user, uint itemlevel) internal view returns (uint){
        uint a = randonmNumber(user, bytes32(block.timestamp));
        if(itemlevel == 2){
            if (a>=9500){
                return 2;
            }else{
                return 1;
            }
        }
        if (itemlevel >=3 && itemlevel <=6){
             if (a>=9500){
                return itemlevel;
             }else if(a>=7000){
                 return itemlevel-1;
             }else{
                 return itemlevel-2;
             }
        }
    }
    
}