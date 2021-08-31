// CryptoKitties Source code
// Copied from: https://etherscan.io/address/0x06012c8cf97bead5deae237070f9587f8e7a266d#code

pragma solidity ^0.4.22;

contract ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);

    function transferFrom(address from, address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract Ownable {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

    mapping(address => bool) public admins;
    modifier onlyAdmin() {
        require( admins[msg.sender]);
        _;
    }
}

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

    function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}

contract SubBase {
    ERC721 public nonFungibleContract;
    ERC20 public fungibleContract;
    bytes4 constant InterfaceSignature_ERC721 = bytes4(0x9a20483d);

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return (nonFungibleContract.ownerOf(_tokenId) == _claimant);
    }

    function _escrow(address _owner, uint256 _tokenId) internal {
        // it will throw if transfer fails
        nonFungibleContract.transferFrom(_owner, this, _tokenId);
    }

    function _transfer(address _receiver, uint256 _tokenId) internal {
        // it will throw if transfer fails
        nonFungibleContract.transfer(_receiver, _tokenId);
    }
    function _createRandom() internal view returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.difficulty, now)));
    }
}

contract ClockPledge is Ownable, SubBase {

    struct Pledge {
        uint256 value;
        uint64 startedAt;
    }

    event AuctionPledgeCreated(address owner, uint256 value);
    event AuctionPledgeCancelled(address owner, uint256 value);

    event TamePledgeCreated(address owner, uint256 value);
    event TamePledgeCancelled(address owner, uint256 value);

    event BreedPledgeCreated(address owner, uint256 value);
    event BreedPledgeCancelled(address owner, uint256 value);

    mapping (address => Pledge) tamePledge;
    mapping (address => uint256) auctionValues;
    mapping (address => uint256) breedValues;


    mapping (address => uint256) stakes;

    constructor(address _nftAddress) public{
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
        owner = msg.sender;
    }

    function setERC20Address(address _address) external onlyOwner {
        fungibleContract = ERC20(_address);
    }

    function createTamePledge(uint256 _value) public {
        Pledge storage pledge = tamePledge[msg.sender];
        require(pledge.value==0, "cannot add pledge");

        fungibleContract.transferFrom(msg.sender, this, _value);

        //        if (pledge.startedAt != 0) {
        //            stakes[msg.sender] = stakes[msg.sender] + ((now-pledge.startedAt)*(pledge.value))/(3600*24);
        //        }
        pledge.value += _value;
        pledge.startedAt =uint64(now);

        emit TamePledgeCreated(msg.sender, _value);
    }

    function cancelTamePledge() public {
        uint256 value=tamePledge[msg.sender].value;
        require(value>0, "no pledge");
        fungibleContract.transfer(msg.sender, value);
        emit TamePledgeCancelled(msg.sender, value);
        delete tamePledge[msg.sender];
    }

    function getTameStake(address _own) public view
    returns(uint256)
    {
        Pledge storage pledge = tamePledge[_own];
        //        uint256 _stake = stakes[_own] + ((now-pledge.startedAt)*(pledge.value))/(3600*24);
        uint256 _stake = ((now-pledge.startedAt)*(pledge.value))/(3600*24);
        return _stake;
    }


    function getTameValue(address _own) external view returns(uint256) {
        return tamePledge[_own].value;
    }

    function updateTamePledgeTime(address _own) onlyAdmin public {
        Pledge storage pledge = tamePledge[_own];
        require(pledge.startedAt >0);
        pledge.startedAt = uint64(now);
        delete stakes[msg.sender];
        tamePledge[_own] = pledge;
    }

    function createAuctionPledge(uint256 _value) public {
        require(auctionValues[msg.sender]==0, "cannot add pledge");
        fungibleContract.transferFrom(msg.sender, this, _value);

        auctionValues[msg.sender]=_value;
        emit AuctionPledgeCreated(msg.sender, _value);
    }

    function cancelAuctionPledge() public {
        uint256 value=auctionValues[msg.sender];
        require(value>0, "no pledge");
        fungibleContract.transfer(msg.sender, value);
        emit AuctionPledgeCancelled(msg.sender, value);
        delete auctionValues[msg.sender];
    }

    function getAuctionValue(address _own) external view returns(uint256) {
        return auctionValues[_own];
    }

    function createBreedPledge(uint256 _value) public {
        require(breedValues[msg.sender]==0, "cannot add pledge");
        fungibleContract.transferFrom(msg.sender, this, _value);

        breedValues[msg.sender]=_value;
        emit BreedPledgeCreated(msg.sender, _value);
    }

    function cancelBreedPledge() public {
        uint256 value=breedValues[msg.sender];
        require(value>0, "no pledge");
        fungibleContract.transfer(msg.sender, value);
        emit BreedPledgeCancelled(msg.sender, value);
        delete breedValues[msg.sender];
    }

    function getBreedValue(address _own) external view returns(uint256) {
        return breedValues[_own];
    }

    function addAdmin(address _new) public onlyOwner {
        admins[_new] = true;
    }

    function deleteAdmin(address _new) public onlyOwner {
        delete admins[_new];
    }
}
