pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;



import "./library/SafeERC20.sol";
import "./item.sol"; 

contract Monster {
    
    using SafeMath for uint;
    
    struct MonsterInfo{
        uint level;
        uint coin;
        uint items;
        uint time;
    }

    struct FightRecord{
        bytes32 monstid;
        address fighter;
        bool status;
        uint start_timestamp;
        uint end_timestamp;
        uint reward_tokens;
        uint reward_item;
        uint reward_item_level;
    }
    
    mapping(bytes32 => MonsterInfo) public allMonster;

    mapping(uint => FightRecord) public allFightRecords;

    uint public monstherRecord = 10000;


    event StartFight(address indexed,uint indexed fightId, uint timestamp);
    event CollectReward(address indexed, uint indexed fightId, uint timestamp);

    address public governance;

    address userAddress;
    
    Item private items; 

    constructor()public{
        governance = msg.sender;
        bytes32 id = toByte32(1);
        allMonster[id].level = 1;
        allMonster[id].coin = 10;
        allMonster[id].items = 1;
        allMonster[id].time = 5 minutes;
    }

    function toByte32(uint x) internal returns (bytes32){
        bytes32 b = bytes32(x);
        return b;
    }

    modifier onlyOwner(){
        require(governance==msg.sender,"not owner");
        _;
    }

    modifier onlyUserAddr(){
        require(userAddress == msg.sender,"not user Address");
        _;
    }

    function setItem(address itemAddress) public onlyOwner {
        items = Item(itemAddress);
    }
    
    function setUser(address addr) public onlyOwner{
        userAddress = addr;
    }

    function fightMonster(address user, bytes32 monsterid) public onlyUserAddr returns (uint){
        require(allMonster[monsterid].level > 0 ,"error monster");
        uint id = monstherRecord;
        allFightRecords[id].monstid = monsterid;
        allFightRecords[id].fighter = user;
        allFightRecords[id].status = true;
        allFightRecords[id].start_timestamp = block.timestamp;
        monstherRecord = monstherRecord.add(1);
        emit StartFight(user, id, block.timestamp);
        return id;

    }

    struct RewardRes{
        bool status;
        uint level;
        uint itemAmount;
        uint tokenAmount;
    }

    function collectMonsterReward(address user, uint fightId) public onlyUserAddr returns(RewardRes memory){
        require(allFightRecords[fightId].fighter == user,"not yours");
        require(allFightRecords[fightId].status == true,"already finished");
        require(allFightRecords[fightId].start_timestamp + allMonster[allFightRecords[fightId].monstid].time <= block.timestamp,"not ready");
        allFightRecords[fightId].end_timestamp = block.timestamp;
        allFightRecords[fightId].status = false;
        allFightRecords[fightId].reward_tokens = 1;
        allFightRecords[fightId].reward_item = 1;
        allFightRecords[fightId].reward_item_level = 1;
        emit CollectReward(user, fightId, block.timestamp);
        RewardRes memory reward ;
        reward.status = true;
        reward.level = allFightRecords[fightId].reward_item_level;
        reward.itemAmount =  allFightRecords[fightId].reward_item;
        reward.tokenAmount = allFightRecords[fightId].reward_tokens;
        return reward;
    }

}