pragma solidity ^0.5.7;

interface ISwaps {
    event OrderCreated(
        bytes32 id,
        address indexed owner,
        address indexed baseAddress,
        address indexed quoteAddress,
        uint baseLimit,
        uint quoteLimit,
        uint expirationTimestamp
    );

    function createOrder(
        address _baseAddress,
        address _quoteAddress,
        uint _baseLimit,
        uint _quoteLimit,
        uint _expirationTimestamp
    ) external;
}
