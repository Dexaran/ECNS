pragma solidity ^0.4.9;

import './AbstractENS.sol';
import "github.com/Arachnid/solidity-stringutils/strings.sol";

/**
 * The ECNS registry contract.
 */
contract ECNS is AbstractENS {
    using strings for *;
    
    struct Record {
        address owner;
        address resolver;
        uint64 ttl;
    }

    mapping(bytes32=>Record) records;

    // Permits modifications only by the owner of the specified node.
    modifier only_owner(bytes32 node) {
        if (records[node].owner != msg.sender) throw;
        _;
    }

    /**
     * Constructs a new ENS registrar.
     */
    function ENS() {
        records[0].owner = msg.sender;
    }

    /**
     * Returns the address that owns the specified node.
     */
    function owner(bytes32 node) constant returns (address) {
        return records[node].owner;
    }

    /**
     * Returns the address of the resolver for the specified node.
     */
    function resolver(bytes32 node) constant returns (address) {
        return records[node].resolver;
    }

    /**
     * Returns the TTL of a node, and any records associated with it.
     */
    function ttl(bytes32 node) constant returns (uint64) {
        return records[node].ttl;
    }

    /**
     * Transfers ownership of a node to a new address. May only be called by the current
     * owner of the node.
     * @param node The node to transfer ownership of.
     * @param owner The address of the new owner.
     */
    function setOwner(bytes32 node, address owner) only_owner(node) {
        Transfer(node, owner);
        records[node].owner = owner;
    }

    /**
     * Transfers ownership of a subnode sha3(node, label) to a new address. May only be
     * called by the owner of the parent node.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     */
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) only_owner(node) {
        var subnode = sha3(node, label);
        NewOwner(node, label, owner);
        records[subnode].owner = owner;
    }

    /**
     * Sets the resolver address for the specified node.
     * @param node The node to update.
     * @param resolver The address of the resolver.
     */
    function setResolver(bytes32 node, address resolver) only_owner(node) {
        NewResolver(node, resolver);
        records[node].resolver = resolver;
    }

    /**
     * Sets the TTL for the specified node.
     * @param node The node to update.
     * @param ttl The TTL in seconds.
     */
    function setTTL(bytes32 node, uint64 ttl) only_owner(node) {
        NewTTL(node, ttl);
        records[node].ttl = ttl;
    }

    /**
     * Returns the namehash of _name.
     * @param _name String from which you want to make a `namehash`.
     */
    function namehash(string _name) constant returns (bytes32) {
        bytes32 node = 0x0000000000000000000000000000000000000000000000000000000000000000;
        var s = _name.toSlice();
        if(s.compare(''.toSlice()) == 0) {
            return node;
        }
        var delim = ".".toSlice();
        var parts = new string[](s.count(delim) + 1);
        if(parts.length == 0) {
            return sha3(node, sha3(_name));
        }
        
        
        for(uint i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();
        }
        
        for (uint l; l < parts.length; l++) {
            node = sha3(node, sha3(parts[parts.length - l - 1]));
        }
        
        return node;
    }
}
