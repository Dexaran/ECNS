pragma solidity ^0.4.0;

import './AbstractENS.sol';

contract ReverseRegistrar {
    AbstractENS public ens;
    bytes32 public rootNode;

    /**
     * @dev Constructor
     * @param ensAddr The address of the ENS registry.
     * @param node The node hash that this registrar governs.
     */
    function ReverseRegistrar() {
        ens = AbstractENS(0xb96836a066ef81ea038280c733f833f69c23efde); // Our ETC ENS
        rootNode = 0x2f142013fcc88d47bffe42e5d883f6081cbaa75abaa20e7f34f3043bbc8162c9;// .etc TLD
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @return The ENS node hash of the reverse record.
     */
    function claim(address owner) returns (bytes32 node) {
        var label = sha3HexAddress(msg.sender);
        ens.setSubnodeOwner(rootNode, label, owner);
        return sha3(rootNode, label);
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The ENS node hash.
     */
    function node(address addr) constant returns (bytes32 ret) {
        return sha3(rootNode, sha3HexAddress(addr));
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) private returns (bytes32 ret) {
        addr; ret; // Stop warning us about unused variables
        assembly {
            let lookup := 0x3031323334353637383961626364656600000000000000000000000000000000
            let i := 40
        loop:
            i := sub(i, 1)
            mstore8(i, byte(and(addr, 0xf), lookup))
            addr := div(addr, 0x10)
            i := sub(i, 1)
            mstore8(i, byte(and(addr, 0xf), lookup))
            addr := div(addr, 0x10)
            jumpi(loop, i)
            ret := sha3(0, 40)
        }
    }
}
