# ECNS
Implementations for registrars and local resolvers for the Ethereum Classic Name Service.

For documentation of the original ENS system, see [docs.ENS.domains](http://docs.ens.domains/).

# Differences between ENS and ECNS

1. ECNS will not burn funds. There is a special `burn` address at the Registrar that will receive funds at destroy of the `Deed` instead of burning them.

2. ECNS registry natively supports `namehash` algorithm. It is possible to call `namehash(string)` and get its nameHash without having to implement the algorithm by third parties.

3. There is a function to extract stuck ERC20 tokens from each contract: Registry and Registrar.

4. rootNode is `.etc`

#### ECNS contracts are deployed on ETC main net:

Hash Registrar:   [0x7564711a9c72edfb5ca10f2962066c707398121d](https://gastracker.io/addr/0x7564711a9c72edfb5ca10f2962066c707398121d)

Registry:         [0xb96836a066ef81ea038280c733f833f69c23efde](https://gastracker.io/addr/0xb96836a066ef81ea038280c733f833f69c23efde)

Public Resolver:  [0x4fa1fc37a083abe4c53b6304f389042bc0566855](https://gastracker.io/addr/0x4fa1fc37a083abe4c53b6304f389042bc0566855)

Reverse Registrar:[0x9434e3f592f5d63de25dbd54af4bd58b822b6136](https://gastracker.io/addr/0x9434e3f592f5d63de25dbd54af4bd58b822b6136)

#### ECNS contracts are deployed on Rinkeby testnet:

Hash Registrar:   [0xb93d8610e5efae1c7f7bcb5c65cfb58c3346ed0d](https://rinkeby.etherscan.io/address/0xb93d8610e5efae1c7f7bcb5c65cfb58c3346ed0d)

Registry:         [0xB6FedAA1c1a170eecb4d5C1984eA4023aEb91d64](https://rinkeby.etherscan.io/address/0xB6FedAA1c1a170eecb4d5C1984eA4023aEb91d64)

## ECNS.sol
Implementation of the ECNS Registry, the central contract used to look up resolvers and owners for domains.

## FIFSRegistrar.sol
Implementation of a simple first-in-first-served registrar, which issues (sub-)domains to the first account to request them.

## HashRegistrar.sol
Implementation of a registrar based on second-price blind auctions and funds held on deposit, with a renewal process that weights renewal costs according to the change in mean price of registering a domain. Largely untested!

## PublicResolver.sol
Simple resolver implementation that allows the owner of any domain to configure how its name should resolve. One deployment of this contract allows any number of people to use it, by setting it as their resolver in the registry.

# ECNS Registry interface

The ECNS registry is a single central contract that provides a mapping from domain names to owners and resolvers, as described in [EIP 137](https://github.com/ethereum/EIPs/issues/137). 

The ECNS operates on 'nodes' instead of human-readable names; a human readable name is converted to a node using the namehash algorithm, which is as follows:

	def namehash(name):
	  if name == '':
	    return '\0' * 32
	  else:
	    label, _, remainder = name.partition('.')
	    return sha3(namehash(remainder) + sha3(label))

The registry's interface is as follows:

## owner(bytes32 node) constant returns (address)
Returns the owner of the specified node.

## resolver(bytes32 node) constant returns (address)
Returns the resolver for the specified node.

## setOwner(bytes32 node, address owner)
Updates the owner of a node. Only the current owner may call this function.

## setSubnodeOwner(bytes32 node, bytes32 label, address owner)
Updates the owner of a subnode. For instance, the owner of "foo.com" may change the owner of "bar.foo.com" by calling `setSubnodeOwner(namehash("foo.com"), sha3("bar"), newowner)`. Only callable by the owner of `node`.

## setResolver(bytes32 node, address resolver)
Sets the resolver address for the specified node.

# Resolver interface

Resolvers must implement one mandatory method, `has`, and may implement any number of other resource-type specific methods. Resolvers must `throw` when an unimplemented method is called.

## has(bytes32 node, bytes32 kind) constant returns (bool)

Returns true if the specified node has the specified record kind available. Record kinds are defined by each resolver type and standardised in EIPs; currently only "addr" is supported.

`has()` must return false if the corresponding record type specific methods will throw if called.

## addr(bytes32 node) constant returns (address ret)

Implements the addr resource type. Returns the Ethereum address associated with a node if it exists, or `throw`s if it does not.
