pragma solidity ^0.4.11;

/**
 * The interface is needed to extract stuck ERC20 tokens from contracts
 */
contract ERC20Interface {
    uint256 public totalSupply;
    function balanceOf(address who) constant returns (uint256);
    function allowance(address owner, address spender) constant returns (uint256);
    function transfer(address to, uint256 value) returns (bool ok);
    function transferFrom(address from, address to, uint256 value) returns (bool ok);
    function approve(address spender, uint256 value) returns (bool ok);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
