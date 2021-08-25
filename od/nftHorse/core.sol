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

    function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}// CryptoKitties Source code
// Copied from: https://etherscan.io/address/0x06012c8cf97bead5deae237070f9587f8e7a266d#code

pragma solidity ^0.4.22;


contract ERC721 {
    // Required methods
    function totalSupply() public view returns (uint256 total);
    function balanceOf(address _owner) public view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) public view returns (address owner);
    function approve(address _to, uint256 _tokenId) external;
    function transfer(address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;

    // Events
    event Transfer(address from, address to, uint256 tokenId);
    event Approval(address owner, address approved, uint256 tokenId);

    function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}


contract HorseAccessControl {

    address public ceoAddress;
    address public cfoAddress;
    address public cooAddress;

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress);
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress);
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress);
        _;
    }

    modifier onlyCLevel() {
        require(
            msg.sender == cooAddress ||
            msg.sender == ceoAddress ||
            msg.sender == cfoAddress
        );
        _;
    }

    /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0));

        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0));

        cfoAddress = _newCFO;
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0));

        cooAddress = _newCOO;
    }

}

contract HorseBase is HorseAccessControl {
    /*** EVENTS ***/

    /// @dev The Birth event is fired whenever a new kitten comes into existence. This obviously
    ///  includes any time a cat is created through the giveBirth method, but it is also called
    ///  when a new gen0 cat is created.
    event Birth(address owner, uint256 kittyId, uint256 matronId, uint256 sireId, uint256 genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a kitten
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, uint256 tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*** DATA TYPES ***/

    /// @dev The main Horse struct. Every cat in CryptoKitties is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Horse {
        // The Horse's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A cat's genes never change.
        uint256 genes;

        // The timestamp from the block when this cat came into existence.
        uint64 birthTime;

        uint32 matronId;
        uint32 sireId;

        uint16 sireIndex;

        uint16 generation;
        uint16[5] gifts;
        bool sex;  //sex true: male, false: female
    }

    /*** CONSTANTS ***/
    uint16[11] public giftsArr = [12, 12, 12, 12, 12, 15, 9, 7, 5, 3, 1];

    /*** STORAGE ***/

    /// @dev An array containing the Horse struct for all Kitties in existence. The ID
    ///  of each cat is actually an index into this array. Note that ID 0 is a negacat,
    ///  the unHorse, the mythical beast that is the parent of all gen0 cats. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, cat ID 0 is invalid... ;-)
    Horse[] horses;

    /// @dev A mapping from cat IDs to the address that owns them. All cats have
    ///  some valid owner address, even gen0 cats are created with a non-zero owner.
    mapping (uint256 => address) public horseIndexToOwner;

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) ownershipTokenCount;

    /// @dev A mapping from HorseIDs to an address that has been approved to call
    ///  transferFrom(). Each Horse can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public horseIndexToApproved;

    /// @dev A mapping from HorseIDs to an address that has been approved to use
    ///  this Horse for siring via breedWith(). Each Horse can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public sireAllowedToAddress;


    /// @dev Assigns ownership of a specific Horse to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of kittens is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        horseIndexToOwner[_tokenId] = _to;
        // When creating new kittens _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            // once the kitten is transferred also clear sire allowances
            delete sireAllowedToAddress[_tokenId];
            // clear any previously approved ownership exchange
            delete horseIndexToApproved[_tokenId];
        }
        // Emit the transfer event.
        emit Transfer(_from, _to, _tokenId);
    }

    /// @dev An internal method that creates a new kitty and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _matronId The kitty ID of the matron of this cat (zero for gen0)
    /// @param _sireId The kitty ID of the sire of this cat (zero for gen0)
    /// @param _generation The generation number of this cat, must be computed by caller.
    /// @param _genes The kitty's genetic code.
    /// @param _owner The inital owner of this cat, must be non-zero (except for the unHorse, ID 0)
    function _createHorse(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256 _genes,
        address _owner,
        uint16[5] _gifts,
        bool _sex
    )
    internal
    returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createHorse() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));

        Horse memory _horse = Horse({
        genes: _genes,
        birthTime: uint64(now),
        matronId: uint32(_matronId),
        sireId: uint32(_sireId),
        sireIndex: 0,
        generation: uint16(_generation),
        gifts: _gifts,
        sex: _sex
        });
        uint256 newKittenId = horses.push(_horse) - 1;

        // It's probably never going to happen, 4 billion cats is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newKittenId == uint256(uint32(newKittenId)));

        // emit the birth event
        emit Birth(
            _owner,
            newKittenId,
            uint256(_horse.matronId),
            uint256(_horse.sireId),
            _horse.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newKittenId);

        return newKittenId;
    }

    function _createRandom() internal returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.difficulty, now, horses.length)));
    }

    function _createGen0Gifts()
    internal
    returns (uint16[5] gifts)
    {
        uint index = uint(_createRandom()%100);
        uint temp = 0;
        for (uint i=0; i<11;i++) {
            temp = temp + giftsArr[i];
            if (index < temp) {
                temp = i;
                break;
            }
        }
        for (i =0; i <5; i++){
            if (temp == 0) {
                break;
            }
            if (i == 4){
                gifts[i] == temp;
                break;
            }
            index = (uint(_createRandom()%100)%(temp+1));
            gifts[i] = uint16(index);
            temp = temp - index;
        }
    }

    function _mixGifts(uint16[5] _matron, uint16[5] _sire) internal returns(uint16[5] gifts) {
        uint16 m = _matron[0]+_matron[1]+_matron[2]+_matron[3]+_matron[4];
        uint16 s = _sire[0]+_sire[1]+_sire[2]+_sire[3]+_sire[4];
        uint16 temp = (m*3 +s*7)/10 ;
        for (uint i =0; i <5; i++){
            if (temp == 0) {
                break;
            }
            if (i == 4){
                gifts[i] == temp;
                break;
            }
            uint16 index = uint16(_createRandom()%100)%(temp+1);
            gifts[i] = index;
            temp = temp - index;
        }
        return gifts;
    }


}

///  See the HorseCore contract documentation to understand how the various contract facets are arranged.
contract HorseOwnership is HorseBase, ERC721 {

    /// @notice Name and symbol of the non fungible token, as defined in ERC721.
    string public constant name = "NFTHorse";
    string public constant symbol = "NH";

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

    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    ///  Returns true for any standardized interfaces implemented by this contract. We implement
    ///  ERC-165 (obviously!) and ERC-721.
    function supportsInterface(bytes4 _interfaceID) external view returns (bool)
    {
        // DEBUG ONLY
        //require((InterfaceSignature_ERC165 == 0x01ffc9a7) && (InterfaceSignature_ERC721 == 0x9a20483d));

        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == InterfaceSignature_ERC721));
    }

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return horseIndexToOwner[_tokenId] == _claimant;
    }

    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return horseIndexToApproved[_tokenId] == _claimant;
    }

    function _approve(uint256 _tokenId, address _approved) internal {
        horseIndexToApproved[_tokenId] = _approved;
    }

    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
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

    /// @notice Grant another address the right to transfer a specific Horse via
    ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the Horse that can be transferred if this call succeeds.
    /// @dev Required for ERC-721 compliance.
    function approve(
        address _to,
        uint256 _tokenId
    )
    external
    {
        // Only an owner can grant transfer approval.
        require(_owns(msg.sender, _tokenId));

        // Register the approval (replacing any previous approval).
        _approve(_tokenId, _to);

        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a Horse owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the Horse to be transfered.
    /// @param _to The address that should take ownership of the Horse. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the Horse to be transferred.
    /// @dev Required for ERC-721 compliance.
    function transferFrom(
        address _from,
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
        // Check for approval and valid ownership

        require(_isApprovedOrOwner(msg.sender, _tokenId), "ERC721: transfer caller is not owner nor approved");


        // Reassign ownership (also clears pending approvals and emits Transfer event).
        _transfer(_from, _to, _tokenId);
    }

    /// @notice Returns the total number of Kitties currently in existence.
    /// @dev Required for ERC-721 compliance.
    function totalSupply() public view returns (uint) {
        return horses.length - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given Horse.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _tokenId)
    public
    view
    returns (address owner)
    {
        owner = horseIndexToOwner[_tokenId];

        require(owner != address(0));
    }

    /// @notice Returns a list of all Horse IDs assigned to an address.
    /// @param _owner The owner whose Kitties we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive (it walks the entire Horse array looking for cats belonging to owner),
    ///  but it also returns a dynamic array, which is only supported for web3 calls, and
    ///  not contract-to-contract calls.
    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalCats = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all cats have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 catId;

            for (catId = 1; catId <= totalCats; catId++) {
                if (horseIndexToOwner[catId] == _owner) {
                    result[resultIndex] = catId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    function setApprovalForAll(address operator, bool approved) public  {
        require(operator != msg.sender, "ERC721: approve to caller");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
 * @dev See {IERC721-isApprovedForAll}.
 */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {

        address owner = ownerOf(tokenId);
        return (spender == owner || horseIndexToApproved[tokenId] == spender || isApprovedForAll(owner, spender));
    }


}


/// @title A facet of HorseCore that manages Horse siring, gestation, and birth.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the HorseCore contract documentation to understand how the various contract facets are arranged.
contract HorseBreeding is HorseOwnership {

    /// @dev The Pregnant event is fired when two cats successfully breed and the pregnancy
    ///  timer begins for the matron.
    //    event Pregnant(address owner, uint256 matronId, uint256 sireId);

    /// @notice The minimum payment required to use breedWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    uint256 public autoBirthFee = 2 finney;

    /// @dev The address of the sibling contract that is used to implement the sooper-sekret
    ///  genetic combination algorithm.



    /// @dev Checks that a given kitten is able to breed. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending pregnancy.
    function _isReadyToBreed(Horse _horse) internal view returns (bool) {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the cat has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_horse.sireIndex<5) && (_horse.generation == 0);
    }

    /// @dev Check if a sire has authorized breeding with this matron. True if both sire
    ///  and matron have the same owner, or if the sire has given siring permission to
    ///  the matron's owner (via approveSiring()).
    function _isSiringPermitted(uint256 _sireId, uint256 _matronId) internal view returns (bool) {
        address matronOwner = horseIndexToOwner[_matronId];
        address sireOwner = horseIndexToOwner[_sireId];

        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to breed with this sire.
        return (matronOwner == sireOwner || sireAllowedToAddress[_sireId] == matronOwner);
    }

    /// @dev Set the cooldownEndTime for the given Horse, based on its current sireIndex.
    ///  Also increments the sireIndex (unless it has hit the cap).
    /// @param _kitten A reference to the Horse in storage which needs its timer started.
    function _triggerCooldown(Horse storage _kitten) internal {
        _kitten.sireIndex += 1;
    }

    /// @notice Grants approval to another user to sire with one of your Kitties.
    /// @param _addr The address that will be able to sire with your Horse. Set to
    ///  address(0) to clear all siring approvals for this Horse.
    /// @param _sireId A Horse that you own that _addr will now be able to sire with.
    function approveSiring(address _addr, uint256 _sireId)
    external
    {
        require(_owns(msg.sender, _sireId));
        require(horses[_sireId].sex);
        sireAllowedToAddress[_sireId] = _addr;
    }

    /// @dev Updates the minimum payment required for calling giveBirthAuto(). Can only
    ///  be called by the COO address. (This fee is used to offset the gas cost incurred
    ///  by the autobirth daemon).
    function setAutoBirthFee(uint256 val) external onlyCOO {
        autoBirthFee = val;
    }


    /// @notice Checks that a given kitten is able to breed (i.e. it is not pregnant or
    ///  in the middle of a siring cooldown).
    /// @param _horseId reference the id of the kitten, any user can inquire about it
    function isReadyToBreed(uint256 _horseId)
    public
    view
    returns (bool)
    {
        //        require(_horseId > 0);
        Horse storage hor = horses[_horseId];
        return _isReadyToBreed(hor);
    }


    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the Horse struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the Horse struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidMatingPair(
        Horse storage _matron,
        uint256 _matronId,
        Horse storage _sire,
        uint256 _sireId
    )
    private
    view
    returns(bool)
    {
        // A Horse can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // We can short circuit the sibling check (below) if either cat is
        // gen zero (has a matron ID of zero).

        if (_sire.matronId != 0 || _matron.matronId != 0) {
            return false;
        }

        // Everything seems cool! Let's get DTF.
        return true;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair for
    ///  breeding via auction (i.e. skips ownership and siring approval checks).
    function _canBreedWithViaAuction(uint256 _matronId, uint256 _sireId)
    internal
    view
    returns (bool)
    {
        Horse storage matron = horses[_matronId];
        Horse storage sire = horses[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId);
    }

    /// @notice Checks to see if two cats can breed together, including checks for
    ///  ownership and siring approvals. Does NOT check that both cats are ready for
    ///  breeding (i.e. breedWith could still fail until the cooldowns are finished).
    ///  TODO: Shouldn't this check pregnancy and cooldowns?!?
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canBreedWith(uint256 _matronId, uint256 _sireId)
    external
    view
    returns(bool)
    {
        require(_matronId > 0);
        require(_sireId > 0);
        Horse storage matron = horses[_matronId];
        Horse storage sire = horses[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId) &&
        _isSiringPermitted(_sireId, _matronId);
    }

    /// @dev Internal utility function to initiate breeding, assumes that all breeding
    ///  requirements have been checked.
    function _breedWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the Kitties from storage.
        Horse storage sire = horses[_sireId];
        Horse storage matron = horses[_matronId];

        // Mark the matron as pregnant, keeping track of who the sire is.
        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        // Clear siring permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete sireAllowedToAddress[_matronId];
        delete sireAllowedToAddress[_sireId];
    }


}


/// @title all functions related to creating kittens
contract HorseMinting is HorseBreeding {

    uint256 public constant GEN0_CREATION_LIMIT = 6789;

    uint32 public constant GEN0_MALE_CREATION_LIMIT = 6111;
    uint32 public constant GEN0_FEMALE_CREATION_LIMIT = 678;

    uint32 public constant GEN1_CREATION_LIMIT = 3210;

    uint256 public constant WEEK_DURATION = 3600*24*7;
    uint256 public deployTime;

    //初代马公母现有数量
    uint32 public gen0MaleCreatedCount;
    uint32 public gen0FemaleCreatedCount;
    uint32 public gen1CreatedCount;

    // Counts the number of cats the contract owner has created.
    uint256 public gen0CreatedCount;

    function _createGen0Sex()
    internal
    returns (bool)
    {
        uint index = uint(_createRandom()%6789);
        if ((index < GEN0_FEMALE_CREATION_LIMIT) || (gen0MaleCreatedCount == GEN0_MALE_CREATION_LIMIT)) {
            return false;
        }
        return true;
    }

    function _canCreateGen1()
    internal
    returns(bool)
    {
        uint16 index = uint16(_createRandom()%3390);
        if ((index > GEN1_CREATION_LIMIT) || (gen1CreatedCount == GEN1_CREATION_LIMIT)) {
            return false;
        }
        gen1CreatedCount++;
        return true;
    }

    function _createGen1Sex()
    internal
    returns (bool)
    {
        uint index = uint(_createRandom()%2);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function _canCreateGen0Horse() internal returns (bool)
    {
        uint256 index =((now-deployTime)/WEEK_DURATION) + 1;
        //        require(index < 680);
        return (gen0CreatedCount < (index*10));
    }

    function createGen0Horse(address _owner) external onlyCOO returns(uint256) {
        address horseOwner = _owner;
        if (horseOwner == address(0)) {
            horseOwner = cooAddress;
        }
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);
        require(_canCreateGen0Horse());
        bool sex = _createGen0Sex();
        uint256 genes = _createRandom();
        uint16[5] memory gifts = _createGen0Gifts();
        uint256 tokenId= _createHorse(0, 0, 0, genes, _owner, gifts, sex);
        gen0CreatedCount++;
        if (sex) {
            gen0MaleCreatedCount++;
        } else {
            gen0FemaleCreatedCount++;
        }
        return tokenId;
    }

    /// @notice Breed a Horse you own (as matron) with a sire that you own, or for which you
    ///  have previously been given Siring approval. Will either make your cat pregnant, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
    /// @param _matronId The ID of the Horse acting as matron (will end up pregnant if successful)
    /// @param _sireId The ID of the Horse acting as sire (will begin its siring cooldown if successful)
    function breedWithAuto(uint256 _matronId, uint256 _sireId)
    external
    payable
    returns(uint256)
    {
        // Checks for payment.
        //        require(msg.value >= autoBirthFee);

        // Caller must own the matron. 子马最终所有者
        require(_owns(msg.sender, _matronId));

        require(_isSiringPermitted(_sireId, _matronId));

        // Grab a reference to the potential matron
        Horse storage matron = horses[_matronId];

        require(!matron.sex);
        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(matron));

        // Grab a reference to the potential sire
        Horse storage sire = horses[_sireId];

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(sire));
        require(sire.sex);

        // All checks passed, kitty gets pregnant!
        _breedWith(_matronId, _sireId);

        if (!_canCreateGen1()){
            return 0;
        }

        uint256 childGenes = _createRandom();
        uint16[5] memory _gifts = _mixGifts(matron.gifts, sire.gifts);
        bool sex = _createGen1Sex();
        uint256 horseId = _createHorse(_matronId, _sireId, 1, childGenes, msg.sender, _gifts, sex);
        return horseId;
    }

    /// @dev Escrows the NFT, assigning ownership to this contract.
    /// Throws if the escrow fails.
    /// @param _owner - Current owner address of token to escrow.
    /// @param _tokenId - ID of token whose approval to verify.
    function _escrow(address _owner, uint256 _tokenId) internal {
        // it will throw if transfer fails
        _transfer(_owner, this, _tokenId);
    }

    function getHorseGifts(uint256 _tokenId) external view returns (uint256)
    {
        Horse storage hor = horses[_tokenId];
        uint256 gifts = uint256(hor.gifts[0]+hor.gifts[1]+hor.gifts[2]+hor.gifts[3]+hor.gifts[4]);
        return gifts;
    }
}


/// @title CryptoKitties: Collectible, breedable, and oh-so-adorable cats on the Ethereum blockchain.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev The main CryptoKitties contract, keeps track of kittens so they don't wander around and get lost.
contract HorseCore is HorseMinting{

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    /// @notice Creates the main CryptoKitties smart contract instance.
    constructor () public {

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        cooAddress = msg.sender;
        cfoAddress = msg.sender;

        //合约部署时间，计算初代马生产周期
        deployTime = now;

        // start with the mythical kitten 0 - so we don't have generation-0 parent issues
        _createHorse(0, 0, 0, uint256(-1), address(0), [uint16(0),uint16(0),uint16(0),uint16(0),uint16(0)], false);
    }


    /// @notice Returns all the relevant information about a specific kitty.
    /// @param _id The ID of the kitty of interest.
    function getHorse(uint256 _id)
    external
    view
    returns (
        uint256 sireIndex,
        uint256 birthTime,
        uint256 matronId,
        uint256 sireId,
        uint256 generation,
        uint256 genes,
        uint16[5] gifts,
        bool sex
    ) {
        Horse storage hor = horses[_id];
        sireIndex = uint256(hor.sireIndex);
        birthTime = uint256(hor.birthTime);
        matronId = uint256(hor.matronId);
        sireId = uint256(hor.sireId);
        generation = uint256(hor.generation);
        genes = hor.genes;
        gifts = hor.gifts;
        sex=hor.sex;
    }

}



contract HorseAccessControl {

    address public ceoAddress;
    address public cfoAddress;
    address public cooAddress;

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress);
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress);
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress);
        _;
    }

    modifier onlyCLevel() {
        require(
            msg.sender == cooAddress ||
            msg.sender == ceoAddress ||
            msg.sender == cfoAddress
        );
        _;
    }

    /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0));

        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0));

        cfoAddress = _newCFO;
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0));

        cooAddress = _newCOO;
    }

}

contract HorseBase is HorseAccessControl {
    /*** EVENTS ***/

    /// @dev The Birth event is fired whenever a new kitten comes into existence. This obviously
    ///  includes any time a cat is created through the giveBirth method, but it is also called
    ///  when a new gen0 cat is created.
    event Birth(address owner, uint256 kittyId, uint256 matronId, uint256 sireId, uint256 genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a kitten
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, uint256 tokenId);

    /*** DATA TYPES ***/

    /// @dev The main Horse struct. Every cat in CryptoKitties is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Horse {
        // The Horse's genetic code is packed into these 256-bits, the format is
        // sooper-sekret! A cat's genes never change.
        uint256 genes;

        // The timestamp from the block when this cat came into existence.
        uint64 birthTime;

        uint32 matronId;
        uint32 sireId;

        uint16 sireIndex;

        uint16 generation;
        uint16[5] gifts;
        bool sex;  //sex true: male, false: female
    }

    /*** CONSTANTS ***/
    uint16[11] public giftsArr = [12, 12, 12, 12, 12, 15, 9, 7, 5, 3, 1];

    /*** STORAGE ***/

    /// @dev An array containing the Horse struct for all Kitties in existence. The ID
    ///  of each cat is actually an index into this array. Note that ID 0 is a negacat,
    ///  the unHorse, the mythical beast that is the parent of all gen0 cats. A bizarre
    ///  creature that is both matron and sire... to itself! Has an invalid genetic code.
    ///  In other words, cat ID 0 is invalid... ;-)
    Horse[] horses;

    /// @dev A mapping from cat IDs to the address that owns them. All cats have
    ///  some valid owner address, even gen0 cats are created with a non-zero owner.
    mapping (uint256 => address) public horseIndexToOwner;

    // @dev A mapping from owner address to count of tokens that address owns.
    //  Used internally inside balanceOf() to resolve ownership count.
    mapping (address => uint256) ownershipTokenCount;

    /// @dev A mapping from HorseIDs to an address that has been approved to call
    ///  transferFrom(). Each Horse can only have one approved address for transfer
    ///  at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public horseIndexToApproved;

    /// @dev A mapping from HorseIDs to an address that has been approved to use
    ///  this Horse for siring via breedWith(). Each Horse can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public sireAllowedToAddress;


    /// @dev Assigns ownership of a specific Horse to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // Since the number of kittens is capped to 2^32 we can't overflow this
        ownershipTokenCount[_to]++;
        // transfer ownership
        horseIndexToOwner[_tokenId] = _to;
        // When creating new kittens _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            // once the kitten is transferred also clear sire allowances
            delete sireAllowedToAddress[_tokenId];
            // clear any previously approved ownership exchange
            delete horseIndexToApproved[_tokenId];
        }
        // Emit the transfer event.
        emit Transfer(_from, _to, _tokenId);
    }

    /// @dev An internal method that creates a new kitty and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _matronId The kitty ID of the matron of this cat (zero for gen0)
    /// @param _sireId The kitty ID of the sire of this cat (zero for gen0)
    /// @param _generation The generation number of this cat, must be computed by caller.
    /// @param _genes The kitty's genetic code.
    /// @param _owner The inital owner of this cat, must be non-zero (except for the unHorse, ID 0)
    function _createHorse(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256 _genes,
        address _owner,
        uint16[5] _gifts,
        bool _sex
    )
    internal
    returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createHorse() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));

        Horse memory _horse = Horse({
        genes: _genes,
        birthTime: uint64(now),
        matronId: uint32(_matronId),
        sireId: uint32(_sireId),
        sireIndex: 0,
        generation: uint16(_generation),
        gifts: _gifts,
        sex: _sex
        });
        uint256 newKittenId = horses.push(_horse) - 1;

        // It's probably never going to happen, 4 billion cats is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newKittenId == uint256(uint32(newKittenId)));

        // emit the birth event
        emit Birth(
            _owner,
            newKittenId,
            uint256(_horse.matronId),
            uint256(_horse.sireId),
            _horse.genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newKittenId);

        return newKittenId;
    }

    function _createRandom() internal returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.difficulty, now, horses.length)));
    }

    function _createGen0Gifts()
    internal
    returns (uint16[5] gifts)
    {
        uint index = uint(_createRandom()%100);
        uint temp = 0;
        for (uint i=0; i<11;i++) {
            temp = temp + giftsArr[i];
            if (index < temp) {
                temp = i;
                break;
            }
        }
        for (i =0; i <5; i++){
            if (temp == 0) {
                break;
            }
            if (i == 4){
                gifts[i] == temp;
                break;
            }
            index = (uint(_createRandom()%100)%(temp+1));
            gifts[i] = uint16(index);
            temp = temp - index;
        }
    }

    function _mixGifts(uint16[5] _matron, uint16[5] _sire) internal returns(uint16[5] gifts) {
        uint16 m = _matron[0]+_matron[1]+_matron[2]+_matron[3]+_matron[4];
        uint16 s = _sire[0]+_sire[1]+_sire[2]+_sire[3]+_sire[4];
        uint16 temp = (m*3 +s*7)/10 ;
        for (uint i =0; i <5; i++){
            if (temp == 0) {
                break;
            }
            if (i == 4){
                gifts[i] == temp;
                break;
            }
            uint16 index = uint16(_createRandom()%100)%(temp+1);
            gifts[i] = index;
            temp = temp - index;
        }
        return gifts;
    }

}

///  See the HorseCore contract documentation to understand how the various contract facets are arranged.
contract HorseOwnership is HorseBase, ERC721 {

    /// @notice Name and symbol of the non fungible token, as defined in ERC721.
    string public constant name = "NFTHorse";
    string public constant symbol = "NH";

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

    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    ///  Returns true for any standardized interfaces implemented by this contract. We implement
    ///  ERC-165 (obviously!) and ERC-721.
    function supportsInterface(bytes4 _interfaceID) external view returns (bool)
    {
        // DEBUG ONLY
        //require((InterfaceSignature_ERC165 == 0x01ffc9a7) && (InterfaceSignature_ERC721 == 0x9a20483d));

        return ((_interfaceID == InterfaceSignature_ERC165) || (_interfaceID == InterfaceSignature_ERC721));
    }

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return horseIndexToOwner[_tokenId] == _claimant;
    }

    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return horseIndexToApproved[_tokenId] == _claimant;
    }

    function _approve(uint256 _tokenId, address _approved) internal {
        horseIndexToApproved[_tokenId] = _approved;
    }

    function balanceOf(address _owner) public view returns (uint256 count) {
        return ownershipTokenCount[_owner];
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

    /// @notice Grant another address the right to transfer a specific Horse via
    ///  transferFrom(). This is the preferred flow for transfering NFTs to contracts.
    /// @param _to The address to be granted transfer approval. Pass address(0) to
    ///  clear all approvals.
    /// @param _tokenId The ID of the Horse that can be transferred if this call succeeds.
    /// @dev Required for ERC-721 compliance.
    function approve(
        address _to,
        uint256 _tokenId
    )
    external
    {
        // Only an owner can grant transfer approval.
        require(_owns(msg.sender, _tokenId));

        // Register the approval (replacing any previous approval).
        _approve(_tokenId, _to);

        // Emit approval event.
        emit Approval(msg.sender, _to, _tokenId);
    }

    /// @notice Transfer a Horse owned by another address, for which the calling address
    ///  has previously been granted transfer approval by the owner.
    /// @param _from The address that owns the Horse to be transfered.
    /// @param _to The address that should take ownership of the Horse. Can be any address,
    ///  including the caller.
    /// @param _tokenId The ID of the Horse to be transferred.
    /// @dev Required for ERC-721 compliance.
    function transferFrom(
        address _from,
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
        // Check for approval and valid ownership
        require(_approvedFor(msg.sender, _tokenId));
        require(_owns(_from, _tokenId));

        // Reassign ownership (also clears pending approvals and emits Transfer event).
        _transfer(_from, _to, _tokenId);
    }

    /// @notice Returns the total number of Kitties currently in existence.
    /// @dev Required for ERC-721 compliance.
    function totalSupply() public view returns (uint) {
        return horses.length - 1;
    }

    /// @notice Returns the address currently assigned ownership of a given Horse.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _tokenId)
    external
    view
    returns (address owner)
    {
        owner = horseIndexToOwner[_tokenId];

        require(owner != address(0));
    }

    /// @notice Returns a list of all Horse IDs assigned to an address.
    /// @param _owner The owner whose Kitties we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. First, it's fairly
    ///  expensive (it walks the entire Horse array looking for cats belonging to owner),
    ///  but it also returns a dynamic array, which is only supported for web3 calls, and
    ///  not contract-to-contract calls.
    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalCats = totalSupply();
            uint256 resultIndex = 0;

            // We count on the fact that all cats have IDs starting at 1 and increasing
            // sequentially up to the totalCat count.
            uint256 catId;

            for (catId = 1; catId <= totalCats; catId++) {
                if (horseIndexToOwner[catId] == _owner) {
                    result[resultIndex] = catId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

}



/// @title A facet of HorseCore that manages Horse siring, gestation, and birth.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the HorseCore contract documentation to understand how the various contract facets are arranged.
contract HorseBreeding is HorseOwnership {

    /// @dev The Pregnant event is fired when two cats successfully breed and the pregnancy
    ///  timer begins for the matron.
    //    event Pregnant(address owner, uint256 matronId, uint256 sireId);

    /// @notice The minimum payment required to use breedWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    uint256 public autoBirthFee = 2 finney;

    /// @dev The address of the sibling contract that is used to implement the sooper-sekret
    ///  genetic combination algorithm.



    /// @dev Checks that a given kitten is able to breed. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending pregnancy.
    function _isReadyToBreed(Horse _horse) internal view returns (bool) {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the cat has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_horse.sireIndex<5) && (_horse.generation == 0);
    }

    /// @dev Check if a sire has authorized breeding with this matron. True if both sire
    ///  and matron have the same owner, or if the sire has given siring permission to
    ///  the matron's owner (via approveSiring()).
    function _isSiringPermitted(uint256 _sireId, uint256 _matronId) internal view returns (bool) {
        address matronOwner = horseIndexToOwner[_matronId];
        address sireOwner = horseIndexToOwner[_sireId];

        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to breed with this sire.
        return (matronOwner == sireOwner || sireAllowedToAddress[_sireId] == matronOwner);
    }

    /// @dev Set the cooldownEndTime for the given Horse, based on its current sireIndex.
    ///  Also increments the sireIndex (unless it has hit the cap).
    /// @param _kitten A reference to the Horse in storage which needs its timer started.
    function _triggerCooldown(Horse storage _kitten) internal {
        _kitten.sireIndex += 1;
    }

    /// @notice Grants approval to another user to sire with one of your Kitties.
    /// @param _addr The address that will be able to sire with your Horse. Set to
    ///  address(0) to clear all siring approvals for this Horse.
    /// @param _sireId A Horse that you own that _addr will now be able to sire with.
    function approveSiring(address _addr, uint256 _sireId)
    external
    {
        require(_owns(msg.sender, _sireId));
        require(horses[_sireId].sex);
        sireAllowedToAddress[_sireId] = _addr;
    }

    /// @dev Updates the minimum payment required for calling giveBirthAuto(). Can only
    ///  be called by the COO address. (This fee is used to offset the gas cost incurred
    ///  by the autobirth daemon).
    function setAutoBirthFee(uint256 val) external onlyCOO {
        autoBirthFee = val;
    }


    /// @notice Checks that a given kitten is able to breed (i.e. it is not pregnant or
    ///  in the middle of a siring cooldown).
    /// @param _horseId reference the id of the kitten, any user can inquire about it
    function isReadyToBreed(uint256 _horseId)
    public
    view
    returns (bool)
    {
        //        require(_horseId > 0);
        Horse storage hor = horses[_horseId];
        return _isReadyToBreed(hor);
    }


    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the Horse struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the Horse struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidMatingPair(
        Horse storage _matron,
        uint256 _matronId,
        Horse storage _sire,
        uint256 _sireId
    )
    private
    view
    returns(bool)
    {
        // A Horse can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // We can short circuit the sibling check (below) if either cat is
        // gen zero (has a matron ID of zero).

        if (_sire.matronId != 0 || _matron.matronId != 0) {
            return false;
        }

        // Everything seems cool! Let's get DTF.
        return true;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair for
    ///  breeding via auction (i.e. skips ownership and siring approval checks).
    function _canBreedWithViaAuction(uint256 _matronId, uint256 _sireId)
    internal
    view
    returns (bool)
    {
        Horse storage matron = horses[_matronId];
        Horse storage sire = horses[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId);
    }

    /// @notice Checks to see if two cats can breed together, including checks for
    ///  ownership and siring approvals. Does NOT check that both cats are ready for
    ///  breeding (i.e. breedWith could still fail until the cooldowns are finished).
    ///  TODO: Shouldn't this check pregnancy and cooldowns?!?
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canBreedWith(uint256 _matronId, uint256 _sireId)
    external
    view
    returns(bool)
    {
        require(_matronId > 0);
        require(_sireId > 0);
        Horse storage matron = horses[_matronId];
        Horse storage sire = horses[_sireId];
        return _isValidMatingPair(matron, _matronId, sire, _sireId) &&
        _isSiringPermitted(_sireId, _matronId);
    }

    /// @dev Internal utility function to initiate breeding, assumes that all breeding
    ///  requirements have been checked.
    function _breedWith(uint256 _matronId, uint256 _sireId) internal {
        // Grab a reference to the Kitties from storage.
        Horse storage sire = horses[_sireId];
        Horse storage matron = horses[_matronId];

        // Mark the matron as pregnant, keeping track of who the sire is.
        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        // Clear siring permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete sireAllowedToAddress[_matronId];
        delete sireAllowedToAddress[_sireId];
    }


}


/// @title all functions related to creating kittens
contract HorseMinting is HorseBreeding {

    uint256 public constant GEN0_CREATION_LIMIT = 6789;

    uint32 public constant GEN0_MALE_CREATION_LIMIT = 6111;
    uint32 public constant GEN0_FEMALE_CREATION_LIMIT = 678;

    uint32 public constant GEN1_CREATION_LIMIT = 3210;

    uint256 public constant WEEK_DURATION = 3600*24*7;
    uint256 public deployTime;

    //初代马公母现有数量
    uint32 public gen0MaleCreatedCount;
    uint32 public gen0FemaleCreatedCount;
    uint32 public gen1CreatedCount;

    // Counts the number of cats the contract owner has created.
    uint256 public gen0CreatedCount;

    function _createGen0Sex()
    internal
    returns (bool)
    {
        uint index = uint(_createRandom()%6789);
        if ((index < GEN0_FEMALE_CREATION_LIMIT) || (gen0MaleCreatedCount == GEN0_MALE_CREATION_LIMIT)) {
            return false;
        }
        return true;
    }

    function _canCreateGen1()
    internal
    returns(bool)
    {
        uint16 index = uint16(_createRandom()%3390);
        if ((index > GEN1_CREATION_LIMIT) || (gen1CreatedCount == GEN1_CREATION_LIMIT)) {
            return false;
        }
        gen1CreatedCount++;
        return true;
    }

    function _createGen1Sex()
    internal
    returns (bool)
    {
        uint index = uint(_createRandom()%2);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function _canCreateGen0Horse() internal returns (bool)
    {
        uint256 index =((now-deployTime)/WEEK_DURATION) + 1;
        //        require(index < 680);
        return (gen0CreatedCount < (index*10));
    }

    function createGen0Horse(address _owner) external onlyCOO {
        address horseOwner = _owner;
        if (horseOwner == address(0)) {
            horseOwner = cooAddress;
        }
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);
        require(_canCreateGen0Horse());
        bool sex = _createGen0Sex();
        uint256 genes = _createRandom();
        uint16[5] memory gifts = _createGen0Gifts();
        _createHorse(0, 0, 0, genes, _owner, gifts, sex);
        gen0CreatedCount++;
        if (sex) {
            gen0MaleCreatedCount++;
        } else {
            gen0FemaleCreatedCount++;
        }
    }

    /// @notice Breed a Horse you own (as matron) with a sire that you own, or for which you
    ///  have previously been given Siring approval. Will either make your cat pregnant, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
    /// @param _matronId The ID of the Horse acting as matron (will end up pregnant if successful)
    /// @param _sireId The ID of the Horse acting as sire (will begin its siring cooldown if successful)
    function breedWithAuto(uint256 _matronId, uint256 _sireId)
    external
    payable
    returns(uint256)
    {
        // Checks for payment.
        //        require(msg.value >= autoBirthFee);

        // Caller must own the matron. 子马最终所有者
        require(_owns(msg.sender, _matronId));

        require(_isSiringPermitted(_sireId, _matronId));

        // Grab a reference to the potential matron
        Horse storage matron = horses[_matronId];

        require(!matron.sex);
        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(matron));

        // Grab a reference to the potential sire
        Horse storage sire = horses[_sireId];

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(sire));
        require(sire.sex);

        // All checks passed, kitty gets pregnant!
        _breedWith(_matronId, _sireId);

        if (!_canCreateGen1()){
            return 0;
        }

        uint256 childGenes = _createRandom();
        uint16[5] memory _gifts = _mixGifts(matron.gifts, sire.gifts);
        bool sex = _createGen1Sex();
        uint256 horseId = _createHorse(_matronId, _sireId, 1, childGenes, msg.sender, _gifts, sex);
        return horseId;
    }

    /// @dev Escrows the NFT, assigning ownership to this contract.
    /// Throws if the escrow fails.
    /// @param _owner - Current owner address of token to escrow.
    /// @param _tokenId - ID of token whose approval to verify.
    function _escrow(address _owner, uint256 _tokenId) internal {
        // it will throw if transfer fails
        _transfer(_owner, this, _tokenId);
    }

    function getHorseGifts(uint256 _tokenId) external view returns (uint256)
    {
        Horse storage hor = horses[_tokenId];
        uint256 gifts = uint256(hor.gifts[0]+hor.gifts[1]+hor.gifts[2]+hor.gifts[3]+hor.gifts[4]);
        return gifts;
    }
}


/// @title CryptoKitties: Collectible, breedable, and oh-so-adorable cats on the Ethereum blockchain.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev The main CryptoKitties contract, keeps track of kittens so they don't wander around and get lost.
contract HorseCore is HorseMinting{

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    /// @notice Creates the main CryptoKitties smart contract instance.
    constructor () public {

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        cooAddress = msg.sender;
        cfoAddress = msg.sender;

        //合约部署时间，计算初代马生产周期
        deployTime = now;

        // start with the mythical kitten 0 - so we don't have generation-0 parent issues
        _createHorse(0, 0, 0, uint256(-1), address(0), [uint16(0),uint16(0),uint16(0),uint16(0),uint16(0)], false);
    }


    /// @notice Returns all the relevant information about a specific kitty.
    /// @param _id The ID of the kitty of interest.
    function getHorse(uint256 _id)
    external
    view
    returns (
        uint256 sireIndex,
        uint256 birthTime,
        uint256 matronId,
        uint256 sireId,
        uint256 generation,
        uint256 genes,
        uint16[5] gifts,
        bool sex
    ) {
        Horse storage hor = horses[_id];
        sireIndex = uint256(hor.sireIndex);
        birthTime = uint256(hor.birthTime);
        matronId = uint256(hor.matronId);
        sireId = uint256(hor.sireId);
        generation = uint256(hor.generation);
        genes = hor.genes;
        gifts = hor.gifts;
        sex=hor.sex;
    }

}
