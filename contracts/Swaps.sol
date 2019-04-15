pragma solidity ^0.5.7;

import './ISwaps.sol';
import './utils/OrderUtils.sol';
import './utils/StorageUtils.sol';
import "./utils/KeyUtils.sol";

contract Swaps is ISwaps {
    using OrderUtils for OrderUtils.Order;
    using StorageUtils for StorageUtils.Storage;

    StorageUtils.Storage internal repository;

    function createOrder(
        address _baseAddress,
        address _quoteAddress,
        uint _baseLimit,
        uint _quoteLimit,
        uint _expirationTimestamp
    ) external {
        OrderUtils.Order memory order = OrderUtils.Order(
            msg.sender,
            _baseAddress,
            _quoteAddress,
            _baseLimit,
            _quoteLimit,
            _expirationTimestamp
        );
        bytes32 id = KeyUtils.createKey(order);
        _preCreationValidate(order);
        repository.put(id, order);
        emit OrderCreated(
            id,
            order.owner,
            order.baseAddress,
            order.quoteAddress,
            order.baseLimit,
            order.quoteLimit,
            order.expirationTimestamp
        );
    }

    function _preCreationValidate(OrderUtils.Order memory _order) internal view {
        require(_order.baseAddress != _order.quoteAddress, "Exchanged tokens must be different");
        require(_order.baseLimit > 0, "Base limit must be positive");
        require(_order.quoteLimit > 0, "Quote limit must be positive");
        require(_order.expirationTimestamp > now, "Expiration time must be in future");
    }
}
