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

    event PledgeCreated(address owner, uint256 value);
    event PledgeCancelled(address owner, uint256 value);

    mapping (address => Pledge) addressToPledge;

    mapping (address => uint256) stakes;

    constructor(address _nftAddress) public{
        ERC721 candidateContract = ERC721(_nftAddress);
        nonFungibleContract = candidateContract;
        owner = msg.sender;
    }

    function setERC20Address(address _address) external onlyOwner {
        fungibleContract = ERC20(_address);
    }

    function addPledge(uint256 _value) public {
        fungibleContract.transferFrom(msg.sender, this, _value);
        Pledge storage pledge = addressToPledge[msg.sender];
        if (pledge.startedAt != 0) {
            stakes[msg.sender] = stakes[msg.sender] + ((now-pledge.startedAt)*(pledge.value))/(3600*24);
        }

        pledge.value += _value;
        pledge.startedAt =uint64(now);

        emit PledgeCreated(msg.sender, _value);
    }

    function cancelPledge() public {
        fungibleContract.transfer(msg.sender, addressToPledge[msg.sender].value);
        delete addressToPledge[msg.sender];
        delete stakes[msg.sender];
        emit PledgeCancelled(msg.sender, addressToPledge[msg.sender].value);
    }

    function getCurrentStakeOfAddress(address _own) public view
    returns(uint256)
    {
        Pledge storage pledge = addressToPledge[_own];
        uint256 _stake = stakes[_own] + ((now-pledge.startedAt)*(pledge.value))/(3600*24);
        return _stake;
    }

    function getCurrentPledgeValue(address _own) external view returns(uint256)
    {
        return addressToPledge[_own].value;
    }

    function updatePledgeTime(address _own) onlyAdmin public {
        Pledge storage pledge = addressToPledge[_own];
        require(pledge.startedAt >0);
        pledge.startedAt = uint64(now);
        delete stakes[msg.sender];
        addressToPledge[_own] = pledge;
    }

    function addAdmin(address _new) public onlyOwner {
        admins[_new] = true;
    }

    function deleteAdmin(address _new) public onlyOwner {
        delete admins[_new];
    }
}
