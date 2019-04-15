pragma solidity ^0.5.7;

import "./OrderUtils.sol";

library StorageUtils {
    using OrderUtils for OrderUtils.Order;

    struct Storage {
        mapping (bytes32 => OrderUtils.Order) orders;
    }

    function get(Storage storage _self, bytes32 _id) internal view returns (OrderUtils.Order memory) {
        return _self.orders[_id];
    }

    function put(Storage storage _self, bytes32 _id, OrderUtils.Order memory _order) internal {
        require(get(_self, _id).isNull(), "Order with already exists");
        _self.orders[_id] = _order;
    }

    function remove(Storage storage _self, bytes32 _id) internal {
        require(!get(_self, _id).isNull(), "Order doesn't exist");
        delete _self.orders[_id];
    }
}
