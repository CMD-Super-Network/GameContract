pragma solidity >=0.5.0 <0.6.0;
pragma experimental ABIEncoderV2;

import "./library/SafeMath.sol"; 

contract Item {
    
    using SafeMath for uint;
    
    mapping(address => mapping(address => mapping(uint =>bool))) allowed;
    
    struct Pack {
        uint level;
        bool status;
        address owner;
        address creator;
        uint create_timestamp;
        uint destroy_timestamp;
        bool onSale;
    }
    
    mapping (uint => Pack) packages;
    
    struct ItemInfo{
        uint level;
        bool status;
        address owner;
        address creator;
        uint max_durability;
        uint durability;
        uint create_timestamp;
        uint destroy_timestamp;
        bool onSale;

    }
    
    mapping (uint => ItemInfo) items;
    
    uint ids = 10000;
    
    mapping (uint => uint) public TotalItems;
    mapping (uint => uint) public TotalFragmentPackages;

    mapping(uint =>uint []) allPackages;
    mapping(uint =>uint []) allItems;


    uint constant FragmentNeed = 777;
    
    uint constant ItemNeed = 3;

    event CreateItem(address indexed creator, uint indexed id, uint indexed level, uint timestamp);

    event CreateItemFailed(address indexed creator, uint indexed id, uint indexed timestamp);

    event DestroyItem(address indexed creator, uint indexed id, uint indexed level, uint timestamp);
    
    event CreatePackage(address indexed creator, uint indexed id, uint indexed level, uint timestamp);
    
    event DestroyPackage(address indexed owner, uint indexed id, uint indexed level, uint timestamp);

    // event RepaireItem(address indexed owner, uint indexed itemid, uint indexed packageid, uint amount, uint timestamp);

    address public accessAddr;

    modifier onlyAccess(){
        require(msg.sender == accessAddr,"you can't access it");
        _;
    }
    

    constructor(address addr) public {
        accessAddr = addr;
    }

    // pack 100 piece fragment to 1 package
    function packFragment(address addr, uint level) public onlyAccess returns(uint){
        uint256 id = ids;
         packages[id].level = level;
         packages[id].status = true;
         packages[id].owner = addr;
         packages[id].creator = addr;
         packages[id].create_timestamp = block.timestamp;
         allPackages[level].push(id);
         TotalFragmentPackages[level] = TotalFragmentPackages[level].add(1);
         emit CreatePackage(addr, id, level,block.timestamp);
         ids = ids.add(1);
        
         return id;
    }
    
    // unpack to fragment
    function unpackFragemt(address addr, uint id) public onlyAccess returns(bool){
        packages[id].destroy_timestamp = block.timestamp;
        emit DestroyPackage(addr, id, packages[id].level, block.timestamp);
        return true;
    }
    

    function createItem(address addr, uint level)public onlyAccess returns(uint){
        uint256 id = ids;
        items[id].level = level;
        items[id].status = true;
        items[id].owner = addr;
        items[id].creator = addr;
        items[id].max_durability = 1000;
        items[id].durability = 1000;
        items[id].create_timestamp = block.timestamp;
        ids = ids.add(1);
        TotalItems[level] = TotalItems[level].add(1);
        allItems[level].push(id);
        emit CreateItem(addr, id, items[id].level,block.timestamp);
        return id;
    }


    function upgradeItem(address addr, uint item1, uint item2,uint  item3)public onlyAccess returns(bool){
        require(items[item1].owner == addr && items[item2].owner == addr && items[item3].owner == addr,"items are not yours");
        require(items[item1].destroy_timestamp ==0 && items[item2].destroy_timestamp == 0 && items[item3].destroy_timestamp == 0 ,"some of items has been destoried, please choose others");
        require(items[item1].durability == items[item1].max_durability && items[item2].durability == items[item2].max_durability && items[item3].durability == items[item3].max_durability,"need repair all items first");
        require(items[item1].level == items[item2].level && items[item1].level == items[item2].level,"need same level of items");
        require(items[item1].level <6,"6 is highest level");
        uint r = randonmNumber(addr,bytes32(item1+item2+item3));
        bool f = false;
        // uint level = getItemInformation(item1).level;
        if(items[item1].level == 1){
            if(r>=2000){
                f = true;
            }
        }else if(items[item1].level == 2){
            if(r>=3000){
                f = true;
            }
        }else if(items[item1].level == 3){
            if (r>=4000){
                f = true;
            }
        }else if(items[item1].level == 4){
            if (r >=5000){
                f = true;
            }
        }else if(items[item1].level == 5){
            if (r >= 6000){
                f = true;
            }
        }
        return f;
    }

    function repaireItem(address addr, uint itemid, uint packid)public onlyAccess{
        require(items[itemid].owner == msg.sender,"item is not yours");
        require(packages[packid].owner == msg.sender,"package is not yours");
        require(items[itemid].level == packages[packid].level,"not the same level");
        uint r = randonmNumber(addr,bytes32(itemid+packid))%200 +300;
        uint c = items[itemid].durability.add(r);
        if(c<=items[itemid].max_durability){
            items[itemid].durability = c;
        }else{
            items[itemid].durability = items[itemid].max_durability;
        }
    }


    function randonmNumber(address user, bytes32 id) internal view returns(uint){
        return uint(keccak256(abi.encodePacked(user,user,id,block.timestamp)))%10000;
    }

    function destoryItem(address addr, uint itemid)public onlyAccess{
          
    }

    function destoryPackage(address addr, uint pid)public onlyAccess{
          
    }
    
    function getItemInformation(uint id) public view returns(ItemInfo memory){
        return items[id];
    }
    
    function getPackageInformation(uint id) public view returns (Pack memory){
        return packages[id];
    }
    
    
  
    //--------------------------------------------get All Informations
    function getAllPackages(uint level) public view returns(uint [] memory){
        return allPackages[level];
    }

    function getAllItems(uint level)public view returns(uint[] memory){
        return allItems[level];
    }
    //--------------------------------------------end
    

    //-------------------------------------------- erc721
    // function name() public view returns (string memory){

    // }

    // function symbol() public view returns (string memory){

    // }

    // function tokenURI_Item (uint tokenId) public view returns (ItemInfo memory){

    // }

    // function tokenURI_Pack (uint tokenId) public view returns (Pack memory){

    // }

    // function totalSupply () public view returns(uint){

    // }

    // function balanceOf(address addr) public view returns (uint){

    // }

    function ownerOf(uint tokenId) public view returns(address owner){
        bool flag = false;
        if(items[tokenId].status == true){
            return items[tokenId].owner;
        }else if(packages[tokenId].status == true){
            return packages[tokenId].owner;
        }
        require(flag,"tokenId not exists");
    }

    function approve(address _to, uint _tokenId, uint _type) public {
        if(_type==1){  // is package
            // packages[_tokenID].owner = _to;
            require(packages[_tokenId].owner == msg.sender,"packages is not yours");
            allowed[msg.sender][_to][_tokenId] = false;
            emit Approval(msg.sender, _to, _tokenId);
            // return true;
        }else if(_type == 2) { // is item
            // items[_tokenID].owner = _to;
            require(items[_tokenId].owner == msg.sender,"item is not yours");
            allowed[msg.sender][_to][_tokenId] = false;
            emit Approval(msg.sender, _to, _tokenId);
            // return true;
        }
    }

    // need update user information
    function transfer(address _to, uint _tokenID, uint _type) public returns(bool) {
        if(_type==1){  // is package
            require(packages[_tokenID].owner == msg.sender,"packages is not yours");
            packages[_tokenID].owner = _to;
            emit Transfer(msg.sender, _to, _tokenID);
            return true;
        }else if(_type == 2) { // is item
            require(items[_tokenID].owner == msg.sender,"item is not yours");
            items[_tokenID].owner = _to;
            emit Transfer(msg.sender, _to, _tokenID);
            return true;
        }
        return false;
    }

    function transferFrom(address _from, address _to, uint _tokenId, uint _type) public returns (bool){
        require(allowed[_from][msg.sender][_tokenId]==true,"not approved");
        if(_type==1){
            require(packages[_tokenId].owner == _from,"packages not yours");
            packages[_tokenId].owner = _to;
            allowed[_from][msg.sender][_tokenId] = false;
            emit Transfer(_from, _to, _tokenId);
            return true;
        }else if(_type ==2){
            require(items[_tokenId].owner == _from,"item not yours");
            items[_tokenId].owner = _to;
            allowed[_from][msg.sender][_tokenId] = false;
            emit Transfer(_from, _to, _tokenId);
            return true;
        }
        return false;
    }

    // function tokenMetaData_Item(uint _tokenID, uint _type) public view returns (ItemInfo memory){

    // }

    // function tokenMetaData_Pack(uint _tokenID, uint _type) public view returns (Pack memory){

    // }


    //------ event
    event Transfer(address indexed _from, address indexed _to, uint _tokenID);
    event Approval(address indexed _owner, address indexed _approved, uint _tokenID);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    //------ event end

    //-------------------------------------------- end
    
    function bytesToUint(bytes32 b) public view returns (uint256){
        uint256 number;
        for(uint i= 0; i<32; i++){
            number = number + uint8(b[i])*(2**(8*(b.length-(i+1))));
        }
        return  number;
    }
    
}