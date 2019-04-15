pragma solidity ^0.5.7;

import './OrderUtils.sol';

library KeyUtils {
    function createKey(OrderUtils.Order memory _order) internal view returns (bytes32 result) {
        result = 0x0000000000000000000000000000000000000000000000000000000000000000;
        address owner = _order.owner;
        uint expiration = now;
        assembly {
            result := or(result, mul(owner, 0x1000000000000000000000000))
            result := or(result, and(expiration, 0xffffffffffffffffffffffff))
        }
    }
}
