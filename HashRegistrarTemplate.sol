pragma solidity ^0.4.9;


/*

Temporary Hash Registrar
========================

This is a simplified version of a hash registrar. It is purporsefully limited:
names cannot be six letters or shorter, new auctions will stop after 4 years.

The plan is to test the basic features and then move to a new contract in at most
2 years, when some sort of renewal mechanism will be enabled.
*/


import './AbstractENS.sol';
import './ERC20Interface.sol';
import './HashRegistrar.sol';


/**
 * @title Registrar
 * @dev The registrar handles the auction process for each subnode of the node it owns.
 */
contract RegistrarTemplate {
    StrLib lib;
    AbstractENS public ens;
    bytes32 public rootNode;

    mapping (bytes32 => entry) _entries;
    mapping (address => mapping(bytes32 => Deed)) public sealedBids;
    
    enum Mode { Open, Auction, Owned, Forbidden, Reveal, NotYetAvailable }

    uint32 constant totalAuctionLength = 5 days;
    uint32 constant revealPeriod = 48 hours;
    uint32 public constant launchLength = 8 weeks;

    uint constant minPrice = 0.01 ether;
    uint public registryStarted;

    event AuctionStarted(bytes32 indexed hash, uint registrationDate);
    event NewBid(bytes32 indexed hash, address indexed bidder, uint deposit);
    event BidRevealed(bytes32 indexed hash, address indexed owner, uint value, uint8 status);
    event HashRegistered(bytes32 indexed hash, address indexed owner, uint value, uint registrationDate);
    event HashReleased(bytes32 indexed hash, uint value);
    event HashInvalidated(bytes32 indexed hash, string indexed name, uint value, uint registrationDate);

    struct entry {
        Deed deed;
        uint registrationDate;
        uint value;
        uint highestBid;
    }

    // State transitions for names:
    //   Open -> Auction (startAuction)
    //   Auction -> Reveal
    //   Reveal -> Owned
    //   Reveal -> Open (if nobody bid)
    //   Owned -> Open (releaseDeed or invalidateName)
    function state(bytes32 _hash) constant returns (Mode) {
        var entry = _entries[_hash];
        
        if (!isAllowed(_hash, now)) {
            return Mode.NotYetAvailable;
        } else if (now < entry.registrationDate) {
            if (now < entry.registrationDate - revealPeriod) {
                return Mode.Auction;
            } else {
                return Mode.Reveal;
            }
        } else {
            if (entry.highestBid == 0) {
                return Mode.Open;
            } else {
                return Mode.Owned;
            }
        }
    }

    modifier inState(bytes32 _hash, Mode _state) {
        if (state(_hash) != _state) throw;
        _;
    }

    modifier onlyOwner(bytes32 _hash) {
        if (state(_hash) != Mode.Owned || msg.sender != _entries[_hash].deed.owner()) throw;
        _;
    }

    modifier registryOpen() {
        if (now < registryStarted  || now > registryStarted + 4 years || ens.owner(rootNode) != address(this)) throw;
        _;
    }

    function entries(bytes32 _hash) constant returns (Mode, address, uint, uint, uint) {
        entry h = _entries[_hash];
        return (state(_hash), h.deed, h.registrationDate, h.value, h.highestBid);
    }

    /**
     * @dev Constructs a new Registrar, with the provided address as the owner of the root node.
     *
     * @param _ens The address of the ENS
     * @param _rootNode The hash of the rootnode.
     */
    function Registrar(AbstractENS _ens, bytes32 _rootNode, uint _startDate) {
       // ens = _ens;
        lib = StrLib(0xbeBAB9Ab58f8099fbFEb15E14b663615D19304Fa);
        ens = AbstractENS(0x340393F8E83B84491E9dE9b246FD69F3A348a03E);
        rootNode = 0x2f142013fcc88d47bffe42e5d883f6081cbaa75abaa20e7f34f3043bbc8162c9;
        registryStarted = _startDate > 0 ? _startDate : now;
    }
    
    /** 
     * @dev Determines if a name is available for registration yet
     * 
     * Each name will be assigned a random date in which its auction 
     * can be started, from 0 to 8 weeks
     * 
     * @param _hash The hash to start an auction on
     * @param _timestamp The timestamp to query about
     */
    function isAllowed(bytes32 _hash, uint _timestamp) constant returns (bool allowed){
        return _timestamp > getAllowedTime(_hash);
    }

    /** 
     * @dev Returns available date for hash
     * 
     * The available time from the `registryStarted` for a hash is proportional
     * to its numeric value.
     * 
     * @param _hash The hash to start an auction on
     */
    function getAllowedTime(bytes32 _hash) constant returns (uint timestamp) {
        return registryStarted + ((launchLength * (uint(_hash) >> 128)) >> 128);
        // Right shift operator: a >> b == a / 2**b
    }

    /**
     * @dev Assign the owner in ENS, if we're still the registrar
     *
     * @param _hash hash to change owner
     * @param _newOwner new owner to transfer to
     */
    function trySetSubnodeOwner(bytes32 _hash, address _newOwner) internal {
        if (ens.owner(rootNode) == address(this))
            ens.setSubnodeOwner(rootNode, _hash, _newOwner);        
    }

    /**
     * @dev Cancel a bid
     *
     * @param seal The value returned by the shaBid function
     */
    function cancelBid(address bidder, bytes32 seal) {
        Deed bid = sealedBids[bidder][seal];
        
        // If a sole bidder does not `unsealBid` in time, they have a few more days
        // where they can call `startAuction` (again) and then `unsealBid` during
        // the revealPeriod to get back their bid value.
        // For simplicity, they should call `startAuction` within
        // 9 days (2 weeks - totalAuctionLength), otherwise their bid will be
        // cancellable by anyone.
        if (address(bid) == 0
            || now < bid.creationDate() + totalAuctionLength + 2 weeks) throw;

        // Send the canceller 0.5% of the bid, and burn the rest.
        bid.setOwner(msg.sender);
        bid.closeDeed(5);
        sealedBids[bidder][seal] = Deed(0);
        BidRevealed(seal, bidder, 0, 5);
    }

    /**
     * @dev Finalize an auction after the registration date has passed
     *
     * @param _hash The hash of the name the auction is for
     */
    function finalizeAuction(bytes32 _hash) onlyOwner(_hash) {
        entry h = _entries[_hash];
        
        // Handles the case when there's only a single bidder (h.value is zero)
        h.value =  lib.max(h.value, minPrice);
        h.deed.setBalance(h.value, true);

        trySetSubnodeOwner(_hash, h.deed.owner());
        HashRegistered(_hash, h.deed.owner(), h.value, h.registrationDate);
    }

    /**
     * @dev The owner of a domain may transfer it to someone else at any time.
     *
     * @param _hash The node to transfer
     * @param newOwner The address to transfer ownership to
     */
    function transfer(bytes32 _hash, address newOwner) onlyOwner(_hash) {
        if (newOwner == 0) throw;

        entry h = _entries[_hash];
        h.deed.setOwner(newOwner);
        trySetSubnodeOwner(_hash, newOwner);
    }

    /**
     * @dev After some time, or if we're no longer the registrar, the owner can release
     *      the name and get their ether back.
     *
     * @param _hash The node to release
     */
    function releaseDeed(bytes32 _hash) onlyOwner(_hash) {
        entry h = _entries[_hash];
        Deed deedContract = h.deed;
        if (now < h.registrationDate + 1 years && ens.owner(rootNode) == address(this)) throw;

        h.value = 0;
        h.highestBid = 0;
        h.deed = Deed(0);

        _tryEraseSingleNode(_hash);
        deedContract.closeDeed(1000);
        HashReleased(_hash, h.value);        
    }

    /**
     * @dev Submit a name 6 characters long or less. If it has been registered,
     *      the submitter will earn 50% of the deed value. 
     * 
     * We are purposefully handicapping the simplified registrar as a way 
     * to force it into being restructured in a few years.
     *
     * @param unhashedName An invalid name to search for in the registry.
     */
    function invalidateName(string unhashedName) inState(sha3(unhashedName), Mode.Owned) {
        if (lib.strlen(unhashedName) > 6) throw;
        bytes32 hash = sha3(unhashedName);

        entry h = _entries[hash];

        _tryEraseSingleNode(hash);

        if (address(h.deed) != 0) {
            // Reward the discoverer with 50% of the deed
            // The previous owner gets 50%
            h.value = lib.max(h.value, minPrice);
            h.deed.setBalance(h.value/2, false);
            h.deed.setOwner(msg.sender);
            h.deed.closeDeed(1000);
        }

        HashInvalidated(hash, unhashedName, h.value, h.registrationDate);

        h.value = 0;
        h.highestBid = 0;
        h.deed = Deed(0);
    }

    /**
     * @dev Allows anyone to delete the owner and resolver records for a (subdomain of a)
     *      name that is not currently owned in the registrar. If passing, eg, 'foo.bar.eth',
     *      the owner and resolver fields on 'foo.bar.eth' and 'bar.eth' will all be cleared.
     *
     * @param labels A series of label hashes identifying the name to zero out, rooted at the
     *        registrar's root. Must contain at least one element. For instance, to zero 
     *        'foo.bar.eth' on a registrar that owns '.eth', pass an array containing
     *        [sha3('foo'), sha3('bar')].
     */
    function eraseNode(bytes32[] labels) {
        if (labels.length == 0) throw;
        if (state(labels[labels.length - 1]) == Mode.Owned) throw;

        _eraseNodeHierarchy(labels.length - 1, labels, rootNode);
    }

    function _tryEraseSingleNode(bytes32 label) internal {
        if (ens.owner(rootNode) == address(this)) {
            ens.setSubnodeOwner(rootNode, label, address(this));
            var node = sha3(rootNode, label);
            ens.setResolver(node, 0);
            ens.setOwner(node, 0);
        }
    }

    function _eraseNodeHierarchy(uint idx, bytes32[] labels, bytes32 node) internal {
        // Take ownership of the node
        ens.setSubnodeOwner(node, labels[idx], address(this));
        node = sha3(node, labels[idx]);
        
        // Recurse if there are more labels
        if (idx > 0) {
            _eraseNodeHierarchy(idx - 1, labels, node);
        }

        // Erase the resolver and owner records
        ens.setResolver(node, 0);
        ens.setOwner(node, 0);
    }
    
    // function to extract ERC20 stuck tokens
    function extractToken(address _ERC20token) {
        ERC20Interface token = ERC20Interface(_ERC20token);
        token.transfer(msg.sender, token.balanceOf(this));
    }

}