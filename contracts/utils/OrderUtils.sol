pragma solidity ^0.5.7;

library OrderUtils {
    struct Order {
        address owner;
        address baseAddress;
        address quoteAddress;
        uint baseLimit;
        uint quoteLimit;
        uint expirationTimestamp;
    }

    function equals(Order memory _self, Order memory _other) internal pure returns (bool) {
        return (_self.owner == _other.owner)
            && (_self.baseAddress == _other.baseAddress)
            && (_self.quoteAddress == _other.quoteAddress)
            && (_self.baseLimit == _other.baseLimit)
            && (_self.quoteLimit == _other.quoteLimit)
            && (_self.expirationTimestamp == _other.expirationTimestamp);
    }

    function isNull(Order memory _self) internal pure returns (bool) {
        return equals(_self, Order(address(0), address(0), address(0), 0, 0, 0));
    }
}
