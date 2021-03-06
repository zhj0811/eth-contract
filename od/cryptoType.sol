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

    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

    function transferInheritor(address newInheritor) onlyOwner {
        if (newInheritor != address(0)) {
            inheritor = newInheritor;
        }
    }
}

contract CryptoTycoon is Ownable, ERC721{

    struct CatBase {
        string url;
        string parity;
        string platform;
        uint64 totalCount;
        uint64 count;
        uint8 version;
    }

    struct Cat {
        uint8 catType;
        uint64 birth;
    }

    Cat[] cats;
    CatBase[] catBases;

    mapping (uint256 => address) public indexToOwner;
    mapping (uint256 => address) public indexToApproved;
    mapping (address => uint256) ownershipTokenCount;
    mapping (string => uint8) typeToIndex;
    mapping (uint8 => string) indexToType;

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

    function _createCat(uint8 _catType, address _to) internal
    returns (uint)
    {
        Cat memory _cat =Cat({
        catType: _catType,
        birth: uint64(now)
        });

        uint256 newIndex = cats.push(_cat) - 1;
        _transfer(0, _to, newIndex);
        return newIndex;
    }

    function createCat(string _type)
    external
    returns(uint)
    {
        uint8 index = typeToIndex[_type];
        require(index != 0);
        CatBase memory _base = catBases[index];
        require(_base.count<_base.totalCount);
        _base.count++;
        catBases[index] = _base;
        uint _index = _createCat(index, inheritor);
        return _index;
    }

    function addCatType(string _type, uint64 _count, string _url, string _parity, string _plat)
    external
    onlyOwner returns(uint256) {
        require(bytes(_type).length != 0);
        require(typeToIndex[_type] == 0);
        CatBase memory _base;
        _base.url = _url;
        _base.parity = _parity;
        _base.totalCount=_count;
        _base.version = 1;
        _base.platform = _plat;
        uint256 index = catBases.push(_base) -1;
        typeToIndex[_type] = uint8(index);
        indexToType[uint8(index)] = _type;
        return index;
    }

    string public constant name = "CatNFT";
    string public constant symbol = "CTT";


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

    function _initCatBase(string _type, uint64 _count, string _url, string _parity) internal{
        CatBase memory _base = CatBase({
        count: 0,
        version:1,
        parity:_parity,
        platform:"CryptoTycoon",
        totalCount:_count,
        url: _url
        });
        uint256 index = catBases.push(_base) -1;
        // for( uint i=0; i<_count; i++) {
        //     _createCat(uint8(index), inheritor);
        // }
        typeToIndex[_type] = uint8(index);
        indexToType[uint8(index)] = _type;
    }

    function createMultiCats(string _type, uint256 _count)
    external
    onlyOwner {
        uint8 index = typeToIndex[_type];
        require(index != 0);
        CatBase memory _base = catBases[index];
        require(_base.count+_count<=_base.totalCount);
        _base.count =_base.count+uint64(_count);
        catBases[index] = _base;
        for( uint i=0; i<_count; i++) {
            _createCat(uint8(index), inheritor);
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
        _createCat(0, address(0));
        _initCats();
    }

    function getCat(uint256 _id)
    external
    view
    returns(string catType, uint256 birth, string parity, string url, uint8 version, string platform)
    {
        Cat storage cat =cats[_id];
        CatBase storage _base=catBases[cat.catType];
        catType = indexToType[cat.catType];
        birth = uint256(cat.birth);
        url = _base.url;
        parity = _base.parity;
        version = _base.version;
        platform = _base.platform;
    }

    function getCatTypeInfo(string _type)
    external
    view
    returns(string parity, string url, uint8 version, string platform){
        uint8 _index = typeToIndex[_type];
        require(_index < catBases.length);
        CatBase storage _base=catBases[_index];
        url = _base.url;
        parity = _base.parity;
        version = _base.version;
        platform = _base.platform;
    }

}
