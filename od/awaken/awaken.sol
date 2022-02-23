// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract awaken is Ownable {
    address public developer;
    address public mainAddr;
    uint256 constant public singleValue = 158 * 10 ** 15;
    uint256 constant public developerReward = 8 * 10 ** 15;
    uint256 constant public mainReward = singleValue - developerReward;
    mapping(address => int8) private addrTimes;
    int8 constant public awakenLimit = 5;

    uint256 private devBounty;
    uint256 private mainBounty;

    event Received(address sender, uint256 value);

    constructor() {}

    receive() external payable {
        require(msg.value == singleValue, "not single awaken value");
        require(addrTimes[_msgSender()] < awakenLimit, "exceed wake up limit");
        addrTimes[_msgSender()]++;
        devBounty += developerReward;
        mainBounty += mainReward;
        emit Received(_msgSender(), singleValue);
    }

    function setDeveloper(address _dev) public onlyOwner{
        developer = _dev;
    }

    function setMainAddr(address _main) public onlyOwner {
        mainAddr = _main;
    }

    function withdrawDeveloperReward() public {
        require(devBounty>0, "no reward");
        require(developer != address(0), "invalid developer address");
        (bool success, ) = mainAddr.call{value:devBounty}("");
        require(success, "Transfer failed.");
        devBounty=0;
    }

    function withdrawMainReward() public {
        require(mainBounty>0, "no reward");
        require(mainAddr != address(0), "invalid main address");
        (bool success, ) = mainAddr.call{value:mainBounty}("");
        require(success, "Transfer failed.");
        mainBounty=0;
    }
}
