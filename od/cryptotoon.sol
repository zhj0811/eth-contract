// CryptoKitties Source code
// Copied from: https://etherscan.io/address/0x06012c8cf97bead5deae237070f9587f8e7a266d#code

pragma solidity ^0.4.22;

/// @title Interface for contracts conforming to ERC-721: Non-Fungible Tokens
/// @author Dieter Shirley <dete@axiomzen.co> (https://github.com/dete)
contract ERC721 {
    // Required methods
    function totalSupply() public view returns (uint256 total);
    function balanceOf(address _owner) public view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) external view returns (address owner);
    function approve(address _to, uint256 _tokenId) external;
    function transfer(address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;

    // Events
    event Transfer(address from, address to, uint256 tokenId);
    event Approval(address owner, address approved, uint256 tokenId);

    // Optional
    // function name() public view returns (string name);
    // function symbol() public view returns (string symbol);
    // function tokensOfOwner(address _owner) external view returns (uint256[] tokenIds);
    // function tokenMetadata(uint256 _tokenId, string _preferredTransport) public view returns (string infoUrl);

    // ERC-165 Compatibility (https://github.com/ethereum/EIPs/issues/165)
    function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}

contract Ownable {
    address public owner;
    address public inheritor = address(0xaEA6bDee17fE9b4F2c86a3F06202C1Aa03f47172);

    constructor () public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

    function transferInheritor(address newInheritor)
    public onlyOwner {
        if (newInheritor != address(0)) {
            inheritor = newInheritor;
        }
    }
}

contract CryptoTycoon is Ownable, ERC721{

    struct CatBase {
        string name;
        string parity;
        string platform;
        uint64 totalCount;
        uint64 count;
        uint8 version;
    }

    struct Cat {
        uint8 catType;
        uint64 indexOfType;
        uint64 birth;
    }

    Cat[] cats;
    CatBase[] catBases;

    mapping (uint256 => address) public indexToOwner;
    mapping (uint256 => address) public indexToApproved;
    mapping (address => uint256) ownershipTokenCount;
    mapping (string => uint8) typeToIndex;
    mapping (uint8 => string) public indexToType;
    mapping (uint8 => mapping(uint64 => uint256)) tokenIdOfTypeIndex;

    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of kittens is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        indexToOwner[_tokenId] = _to;
        // When creating new kittens _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            delete indexToApproved[_tokenId];
        }
        // Emit the transfer event.
        emit Transfer(_from, _to, _tokenId);
    }

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return indexToOwner[_tokenId] == _claimant;
    }

    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
    }

    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns(bool) {
        return indexToApproved[_tokenId] == _claimant;
    }

    function _approve(uint256 _tokenId, address _approved) internal {
        indexToApproved[_tokenId]=_approved;
    }

    function transfer(
        address _to,
        uint256 _tokenId
    )
    external
    {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        // Disallow transfers to this contract to prevent accidental misuse.
        // The contract should never own any horses (except very briefly
        // after a gen0 cat is created and before it goes on auction).
        require(_to != address(this));
        // Disallow transfers to the auction contracts to prevent accidental
        // misuse. Auction contracts should only take ownership of horses
        // through the allow + transferFrom flow.

        // You can only send your own cat.
        require(_owns(msg.sender, _tokenId));

        // Reassign ownership, clear pending approvals, emit Transfer event.
        _transfer(msg.sender, _to, _tokenId);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external{
        require(_to != address(0));
        require(_approvedFor(msg.sender, _tokenId));
        require(_owns(_from, _tokenId));
        _transfer(_from, _to, _tokenId);
    }

    function _createCat(uint8 _catType, uint64 _indexOfType, address _to) internal
    returns (uint)
    {
        Cat memory _cat =Cat({
        catType: _catType,
        indexOfType: _indexOfType,
        birth: uint64(now)
        });

        uint256 newIndex = cats.push(_cat) - 1;
        _transfer(0, _to, newIndex);
        tokenIdOfTypeIndex[_catType][_indexOfType] = newIndex;
        return newIndex;
    }

    function createCat(string _cid)
    external
    returns(uint)
    {
        uint8 index = typeToIndex[_cid];
        require(index != 0);
        CatBase memory _base = catBases[index];
        require(_base.count<_base.totalCount);
        _base.count++;
        catBases[index] = _base;
        uint _index = _createCat(index, _base.count, inheritor);
        return _index;
    }

    function addCatType(string _cid, uint64 _count, string _name, uint256 _version, string _parity, string _plat)
    external
    onlyOwner returns(uint256) {
        require(bytes(_cid).length != 0);
        require(typeToIndex[_cid] == 0);
        CatBase memory _base;
        _base.name = _name;
        _base.parity = _parity;
        _base.totalCount=_count;
        _base.version = uint8(_version);
        _base.platform = _plat;
        uint256 index = catBases.push(_base) -1;
        typeToIndex[_cid] = uint8(index);
        indexToType[uint8(index)] = _cid;
        return index;
    }

    string public constant name = "CatNFT";
    string public constant symbol = "CTT";

    bytes4 constant InterfaceSignature_ERC165 =
    bytes4(keccak256('supportsInterface(bytes4)'));

    bytes4 constant InterfaceSignature_ERC721 =
    bytes4(keccak256('name()')) ^
    bytes4(keccak256('symbol()')) ^
    bytes4(keccak256('totalSupply()')) ^
    bytes4(keccak256('balanceOf(address)')) ^
    bytes4(keccak256('ownerOf(uint256)')) ^
    bytes4(keccak256('approve(address,uint256)')) ^
    bytes4(keccak256('transfer(address,uint256)')) ^
    bytes4(keccak256('transferFrom(address,address,uint256)')) ^
    bytes4(keccak256('tokensOfOwner(address)')) ^
    bytes4(keccak256('tokenMetadata(uint256,string)'));

    function supportsInterface(bytes4 _interfaceID) external view returns (bool)
    {
        // DEBUG ONLY
        //require((InterfaceSignature_ERC165 == 0x01ffc9a7) && (InterfaceSignature_ERC721 == 0x9a20483d));

        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == InterfaceSignature_ERC721));
    }

    function totalSupply() public view returns (uint) {
        return cats.length - 1;
    }

    function ownerOf(uint256 _tokenId)
    external
    view
    returns (address owner)
    {
        owner = indexToOwner[_tokenId];

        require(owner != address(0));
    }

    function approve(address _to, uint256 _tokenId) external{
        require(_owns(msg.sender, _tokenId));
        _approve(_tokenId, _to);
        emit Approval(msg.sender, _to, _tokenId);
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalcats = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all cats have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 catId;

            for (catId = 1; catId <= totalcats; catId++) {
                if (indexToOwner[catId] == _owner) {
                    result[resultIndex] = catId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    function _initCats() internal {
        _initCatBase("Ragdoll", 10, "Qmb58A31kpyLbek5eRphYiQHn91Df7soLTtEQMn65AANua", "SSR");
        _initCatBase("American Shorthair", 1000, "QmVi3qv6xiM6jeknjatL8x4nkmXW9vHWdU9fLgn4PULtnK", "SR");
        _initCatBase("British Shorthair", 1000, "Qme2bJ3f6kauVPRhytBZwoh3R9fSHohbj4K3Mh32sY1pK9", "SR");
        _initCatBase("Soccer Cat", 500, "QmXFM2rEVGhm78ng1xBrcjbW1Ds87TykVMj5WrVZL6Yt2z", "R");
        _initCatBase("Legendary Rod", 5, "QmVX6wqTy2ZjvJ56mSBzoQfXHRRB2RoGQxxL7Xg7Fz5q96", "SSR");
        _initCatBase("Precious Rod", 20, "QmWZwKG5P953ELwBUR7U4zx61e2x8LkxS5ZJCWQ758AaCr", "SR");
    }

    function _initCatBase(string _name, uint64 _count, string _cid, string _parity) internal{
        CatBase memory _base = CatBase({
        count: 0,
        version:1,
        parity:_parity,
        platform:"CryptoTycoon",
        totalCount:_count,
        name: _name
        });
        uint256 index = catBases.push(_base) -1;
        typeToIndex[_cid] = uint8(index);
        indexToType[uint8(index)] = _cid;
    }

    function createMultiCats(string _cid, uint256 _count)
    external
    onlyOwner {
        uint8 index = typeToIndex[_cid];
        require(index != 0);
        CatBase memory _base = catBases[index];
        require(_base.count+_count<=_base.totalCount);
        uint64 _initCount = _base.count;
        _base.count =_initCount+uint64(_count);
        catBases[index] = _base;
        for( uint64 i=0; i<_count; i++) {
            _createCat(uint8(index), uint64(_initCount+i+1),inheritor);
        }
    }

    constructor () public {
        indexToType[0]="";
        typeToIndex[""]=0;
        CatBase memory _base;
        _base.count=1;
        _base.totalCount =1;
        // uint256 index = catBases.push(_base)-1;
        catBases.push(_base);
        _createCat(0, 1, address(0));
        _initCats();
    }

    function getCat(uint256 _id)
    external
    view
    returns(string cid, uint256 indexOfType, uint256 birth, string parity, string _name, uint8 version, string platform)
    {
        Cat storage cat =cats[_id];
        CatBase storage _base=catBases[cat.catType];
        cid = indexToType[cat.catType];
        birth = uint256(cat.birth);
        _name = _base.name;
        parity = _base.parity;
        version = _base.version;
        platform = _base.platform;
        indexOfType= cat.indexOfType;
    }

    function getCatByTypeIndex(string _cid, uint64 _indexOfType)
    external
    view
    returns(uint256 _tokenId, uint256 birth, string parity, string _name, uint8 version, string platform){
        uint8 _type= typeToIndex[_cid];
        _tokenId = tokenIdOfTypeIndex[_type][_indexOfType];
        Cat storage cat =cats[_tokenId];
        CatBase storage _base =catBases[cat.catType];
        birth = uint256(cat.birth);
        _name = _base.name;
        parity = _base.parity;
        version = _base.version;
        platform = _base.platform;
    }

    function getCatTypeInfo(string _cid)
    external
    view
    returns(string parity, string _name, uint8 version, string platform, uint256 count, uint256 totalCount){
        uint8 _index = typeToIndex[_cid];
        require(_index < catBases.length);
        CatBase storage _base=catBases[_index];
        _name = _base.name;
        parity = _base.parity;
        version = _base.version;
        platform = _base.platform;
        count = _base.count;
        totalCount = _base.totalCount;
    }

    function getCatTypeCount()
    public view
    returns(uint256){
        return cats.length - 1;
    }
}
