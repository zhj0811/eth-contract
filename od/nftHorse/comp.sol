// CryptoKitties Source code
// Copied from: https://etherscan.io/address/0x06012c8cf97bead5deae237070f9587f8e7a266d#code

pragma solidity ^0.4.22;

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

    function getHorseGifts(uint256 tokenId) external view returns(uint256);
}


contract Ownable {
    address public owner;


    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () {
        owner = msg.sender;
    }


    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}

contract SubBase {
    ERC721 public nonFungibleContract;
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
    function _createRandom() internal returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.difficulty, now)));
    }
}



contract ClockCompetition is Ownable, SubBase {

    uint256 public constant MINIMUM_BET_AMOUNT = 500000;
    uint256 public constant CANCEL_CUT_BET_AMOUNT = 100000;
    uint256 public constant WINNER_CUT = 10;
    uint256 public constant CONTRACT_CUT = 10;

    struct Vote {
        address voter;
        uint256 count;
    }
    // Represents an competition on an NFT
    struct Competition {
        // Current owner of NFT
        //        address seller;
        //赛马总计数
        uint16 count;

        //所有赛马_tokenId
        uint256[] horses;
        uint256 winner;
        //        Vote[] bets;
        uint256 totalBetCount ;
        mapping (uint256 => Vote) bets;
        //参赛马匹tokenId=>马所有人
        mapping(uint256 =>address) players;

        //每匹马对应的资金池
        mapping(uint256 => uint256) tokenIdToPool;

        //_tokenId 对应的投注顺序
        mapping(uint256=> uint256[])  tokenIdToBet;
        //总奖池
        uint256 totalPoolValue;
        uint64 duration;
        // Time when competition started
        // NOTE: 0 if this competition has been concluded
        uint64 startedAt;
    }

    // Cut owner takes on each competition, measured in basis points (1/100 of a percent).
    // Values 0-10,000 map to 0%-100%
    uint256 public ownerCut;

    uint256 public totalCompCount;
    uint256 public activeCompCount;


    mapping (uint256 => Competition) compIdToCompetition;

    event CompetitionCreated(uint256 tokenId, uint256 startingPrice, uint256 endingPrice, uint256 duration);
    event CompetitionSuccessful(uint256 tokenId, uint256 totalPrice, address winner);
    event CompetitionCancelled(uint256 tokenId);


    /// @dev Cancels an competition unconditionally.
    function _cancelCompetition(uint256 _compId) internal {
        Competition storage competition = compIdToCompetition[_compId];
        uint256[] storage horses = competition.horses;
        _removeCompetition(_compId);
        for (uint i=0; i< horses.length; i++ ){
            uint256 _tokenId = horses[i];
            _transfer(competition.players[_tokenId], _tokenId);
        }

        for(i =1; i<=competition.totalBetCount; i++ ) {
            Vote bet = competition.bets[i];
            bet.voter.transfer(bet.count-CANCEL_CUT_BET_AMOUNT);
        }

        emit CompetitionCancelled(_compId);
    }

    /// @dev Removes an competition from the list of open competitions.
    /// @param _compId - ID of NFT on competition.
    function _removeCompetition(uint256 _compId) internal {
        delete compIdToCompetition[_compId];
    }

    /// @dev Returns true if the NFT is on competition.
    /// @param _comp - Competition to check.
    function _isOnCompetition(Competition storage _comp) internal view returns (bool) {
        return (_comp.startedAt > 0)&&(now < (_comp.startedAt + _comp.duration));
    }

    function _isExpireCompetition(Competition storage _comp) internal view returns (bool) {
        return (_comp.startedAt > 0)&&(now > (_comp.startedAt + _comp.duration));
    }

    function createCompetition(uint256 _duration, uint256 _count)
    external onlyOwner
    returns (uint256)
    {
        //        Vote[] _votes;
        uint256[] _horses;
        Competition memory comp = Competition({
        count: uint16(_count),
        totalPoolValue:0,
        //        bets: _votes,
        totalBetCount:0,
        horses:_horses,
        winner:0,
        duration: uint64(_duration),
        startedAt:uint64(now)
        });
        require(comp.duration >= 10 minutes);
        uint256 id = totalCompCount++;
        compIdToCompetition[id] = comp;
        return id;
    }

    function addPlayer(uint256 _tokenId, uint256 _compId) external
    {
        Competition storage comp = compIdToCompetition[_compId];

        // Explicitly check that this competition is currently live.
        // (Because of how Ethereum mappings work, we can't just count
        // on the lookup above failing. An invalid _tokenId will just
        // return an competition object that is all zeros.)
        require(_isOnCompetition(comp));
        require(_owns(msg.sender, _tokenId));
        _escrow(msg.sender, _tokenId);
        comp.horses.push(_tokenId);
        comp.players[_tokenId] = msg.sender;
    }

    function addBet(uint256 _tokenId, uint256 _compId)
    external
    payable
    {
        require(MINIMUM_BET_AMOUNT < msg.value);
        Competition storage comp = compIdToCompetition[_compId];

        // Explicitly check that this competition is currently live.
        // (Because of how Ethereum mappings work, we can't just count
        // on the lookup above failing. An invalid _tokenId will just
        // return an competition object that is all zeros.)
        require(_isOnCompetition(comp));
        comp.totalPoolValue +=msg.value;
        // uint256 index =
        comp.totalBetCount +=1;
        //        Vote bet=
        comp.bets[comp.totalBetCount] =Vote(msg.sender, msg.value);
        comp.tokenIdToBet[_tokenId].push(comp.totalBetCount);
        comp.tokenIdToPool[_tokenId] +=msg.value;
    }


    function successComp(uint256 _compId) external onlyOwner
    returns (uint256)
    {
        Competition storage comp = compIdToCompetition[_compId];
        require(_isExpireCompetition(comp));
        uint256 _tokenId = _computeWinner(comp);

        return _tokenId;
    }

    function _computeWinner(Competition storage _comp) internal returns(uint256)
    {
        uint256 tempId;
        uint256 tempResult;
        for(uint i=0; i< _comp.horses.length; i++){
            uint256 _tempTokenId = _comp.horses[i];
            uint256 gifts = nonFungibleContract.getHorseGifts(_tempTokenId);
            uint256 result = _createRandom()/3000 + gifts*700;
            if (result >tempResult) {
                tempResult = result;
                tempId = _tempTokenId;
            }
        }
        _comp.winner=tempId;
        // address  _winner = _comp.players[tempId];
        uint256 winnerValue = _comp.totalPoolValue*WINNER_CUT/10000;
        _comp.players[tempId].transfer(winnerValue);
        uint256 voterValue = _comp.totalPoolValue - _comp.totalPoolValue*CONTRACT_CUT/10000 -winnerValue;
        uint256[] voters = _comp.tokenIdToBet[tempId];
        uint256 winnerPool = _comp.tokenIdToPool[tempId];
        for (i=0; i<voters.length; i++){
            Vote bet = _comp.bets[voters[i]] ;
            bet.voter.transfer(bet.count*voterValue/winnerPool);
        }

        return tempId;
    }

    function getComp(uint256 _id) external view
    returns(uint256 count, uint256[] horses, uint256 totalPoolValue, uint64 duration, uint64 startedAt)
    {
        Competition storage comp = compIdToCompetition[_compId];
        count = uint256(comp.count);
        horses = comp.horses;
        totalPoolValue = comp.totalPoolValue;
        duration = comp.duration;
        startedAt = comp.startedAt;
    }
}
