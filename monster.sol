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
        uint monstid;
        address fighter;
        bool status;
        uint start_timestamp;
        uint end_timestamp;
        uint reward_tokens;
        uint reward_item;
        uint reward_item_level;
    }
    
    mapping(uint => MonsterInfo) public allMonster;

    mapping(uint => FightRecord) public allFightRecords;

    uint public monstherRecord = 10000;


    event StartFight(address indexed,uint indexed fightId, uint timestamp);
    event CollectReward(address indexed, uint indexed fightId, uint timestamp);

    address public governance;

    address userAddress;
    
    Item private items; 

    constructor()public{
        governance = msg.sender;
        allMonster[1].level = 1;
        allMonster[1].coin = 10;
        allMonster[1].items = 1;
        allMonster[1].time = 5 minutes;
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

    function fightMonster(address user, uint monsterid) public onlyUserAddr returns (bool){
        require(allMonster[monsterid].level > 0 ,"error monster");
        uint id = monstherRecord;
        allFightRecords[id].monstid = monsterid;
        allFightRecords[id].fighter = user;
        allFightRecords[id].status = true;
        allFightRecords[id].start_timestamp = block.timestamp;
        monstherRecord = monstherRecord.add(1);
        emit StartFight(user, id, block.timestamp);
        return true;

    }

    function collectMonsterReward(address user, uint fightId) public onlyUserAddr{
        require(allFightRecords[fightId].fighter == user,"not yours");
        require(allFightRecords[fightId].status == true,"already finished");
        require(allFightRecords[fightId].start_timestamp + allMonster[allFightRecords[fightId].monstid].time <= block.timestamp,"not ready");
        allFightRecords[fightId].end_timestamp = block.timestamp;
        allFightRecords[fightId].status = false;
        allFightRecords[fightId].reward_tokens = 1;
        allFightRecords[fightId].reward_item = 1;
        allFightRecords[fightId].reward_item_level = 1;
        emit CollectReward(user, fightId, block.timestamp);
    }

}