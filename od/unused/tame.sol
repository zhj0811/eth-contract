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

contract Pledge {
    function getCurrentStakeOfAddress(address _own) public view returns(uint256);
    function getCurrentPledgeValue(address _own) external view returns(uint256);
    function updatePledgeTime(address _own) public;
}

contract SubBase {
    ERC721 public nonFungibleContract;
    ERC20 public fungibleContract;
    Pledge public pledgeContract;
    bytes4 constant InterfaceSignature_ERC721 = bytes4(0x9a20483d);

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return (nonFungibleContract.ownerOf(_tokenId) == _claimant);
    }

    function _escrow(address _owner, uint256 _tokenId) internal {
        // it will throw if transfer fails
        nonFungibleContract.transferFrom(_owner, this, _tokenId);
    }

    function _transferFrom(uint256 _tokenId) internal {
        address _owner = nonFungibleContract.ownerOf(_tokenId);
        nonFungibleContract.transferFrom(_owner, this, _tokenId);
    }

    function _transfer(address _receiver, uint256 _tokenId) internal {
        // it will throw if transfer fails
        nonFungibleContract.transfer(_receiver, _tokenId);
    }
    function _createRandom() internal returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.difficulty, now)));
    }

    function _getCurrentStakeOfAddress(address _own) internal view returns(uint256)
    {
        return pledgeContract.getCurrentStakeOfAddress(_own);
    }

    function _getCurrentPledgeValue(address _own) internal view returns(uint256)
    {
        return pledgeContract.getCurrentPledgeValue(_own);
    }

    function _updatePledgeTime(address _own) internal{
        return pledgeContract.updatePledgeTime(_own);
    }
}


contract ClockTame is SubBase, Ownable{
    struct Tame {
        uint256[10] horses;
        uint64 startTime;
    }

    event TameCreated(uint256 term);
    event TameSuccessful(uint256 term);

    uint256 periods;
    mapping(uint256 =>Tame) tames;

    mapping(uint256 => mapping(uint256 =>address)) termParties;
    mapping(uint256 => uint256) partCount;


    constructor(address _nftAddress) public{
        ERC721 candidateContract = ERC721(_nftAddress);
        require(candidateContract.supportsInterface(InterfaceSignature_ERC721));
        nonFungibleContract = candidateContract;
        owner = msg.sender;
    }

    function setERC20Address(address _address) external onlyOwner {
        fungibleContract = ERC20(_address);
    }

    function setPledgeAddress(address _address) external onlyOwner {
        pledgeContract = Pledge(_address);
    }

    // function _qsort(uint256[] storage arr, uint256 left, uint256 right) internal {
    //     uint256 i = left;
    //     uint256 j = right;
    //     if (i == j) return;
    //     uint256 pivot = arr[left];
    //     while (i < j) {
    //       	while (i < j &&pivot >= arr[j]) j--;
    // 		 (arr[i], arr[j]) = (arr[j], arr[i]);
    // 		while (i < j &&arr[i] >= pivot) i++;
    // 		 (arr[i], arr[j]) = (arr[j], arr[i]);
    //     }
    //     _qsort(arr, left, i);
    //     _qsort(arr, i+1, right);
    // }

    function createTame(uint256[10] _hs) {
        periods +=1;
        for (uint256 i =0;i<10; i++) {
            _transferFrom(_hs[i]);
        }
        Tame storage _tame;
        _tame.horses = _hs;
        _tame.startTime = uint64(now);
        tames[periods] = _tame;
        emit TameCreated(periods);
    }

    function joinTame(uint256 _term) {
        Tame storage _tame = tames[_term];
        require(_tame.startTime > 0);
        require(_getCurrentPledgeValue(msg.sender)>30);

        termParties[_term][partCount[_term]]=msg.sender;
        partCount[_term]+=1;
        //        _tame.participants.push(msg.sender);
    }

    function endTame(uint256 _term) public onlyOwner {
        Tame storage _tame = tames[_term];
        require(_tame.startTime > 0);
        mapping(uint256=>address) _parties = termParties[_term];
        uint256[] storage stakes;
        require(partCount[_term] >9);
        for(uint256 i=0; i< partCount[_term]; i++) {
            stakes.push(_getCurrentStakeOfAddress(_parties[i]));
        }
        uint256[] storage indexOfWinner;
        for (i =0; i<10; i++) {
            indexOfWinner.push(i);
        }
        for (i =10; i<partCount[_term]; i++ ) {
            uint256 index = i;
            for (uint256 j = 0; j<10 ; j++) {
                if (stakes[index] > stakes[indexOfWinner[j]]) {
                    uint256 temp = indexOfWinner[j];
                    indexOfWinner[j] = index;
                    index = temp;
                }
            }
        }

        for(i=0; i< _tame.horses.length; i++) {
            _escrow(_parties[indexOfWinner[i]], _tame.horses[i]);
            _updatePledgeTime(_parties[indexOfWinner[i]]);
        }
        delete tames[_term];
        delete partCount[_term];
        emit TameSuccessful(_term);
    }
}

