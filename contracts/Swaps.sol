pragma solidity ^0.5.7;

import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import './IERC20.sol';
import './ISwaps.sol';
import './Vault.sol';

contract Swaps is Ownable, ISwaps, ReentrancyGuard {
    using SafeMath for uint;

    uint public MAX_INVESTORS = 10;

    Vault public vault;
    mapping (bytes32 => address) public baseOnlyInvestor;
    mapping (bytes32 => address) public owners;
    mapping (bytes32 => address) public baseAddresses;
    mapping (bytes32 => address) public quoteAddresses;
    mapping (bytes32 => uint) public expirationTimestamps;
    mapping (bytes32 => bool) public isSwapped;
    mapping (bytes32 => bool) public isCancelled;
    mapping (bytes32 => mapping (address => uint)) public limits;
    mapping (bytes32 => mapping (address => uint)) public raised;
    mapping (bytes32 => mapping (address => address[])) public investors;
    mapping (bytes32 => mapping (address => mapping (address => uint))) public investments;
    mapping (bytes32 => mapping (address => uint)) public minInvestments;

    modifier onlyInvestor(bytes32 _id, address _token) {
        require(_isInvestor(_id, _token, msg.sender), "Allowed only for investors");
        _;
    }

    modifier onlyWhenVaultDefined() {
        require(address(vault) != address(0), "Vault is not defined");
        _;
    }

    modifier onlyOrderOwner(bytes32 _id) {
        require(msg.sender == owners[_id]);
        _;
    }

    event OrderCreated(
        bytes32 id,
        address indexed owner,
        address indexed baseAddress,
        address indexed quoteAddress,
        uint baseLimit,
        uint quoteLimit,
        uint expirationTimestamp
    );

    event Cancel(bytes32 id);

    event Deposit(
        bytes32 id,
        address indexed token,
        address indexed user,
        uint amount,
        uint balance
    );

    event Refund(
        bytes32 id,
        address indexed token,
        address indexed user,
        uint amount
    );

    event Swap(
        bytes32 id,
        address indexed byUser
    );

    event SwapSend(
        bytes32 id,
        address indexed token,
        address indexed user,
        uint amount
    );

    function tokenFallback(address, uint, bytes calldata) external {
    }

    function createOrder(
        bytes32 _id,
        address _baseAddress,
        address _quoteAddress,
        uint _baseLimit,
        uint _quoteLimit,
        uint _expirationTimestamp,
        address _baseOnlyInvestor,
        uint _minBaseInvestment,
        uint _minQuoteInvestment
    )
        external
        nonReentrant
        onlyWhenVaultDefined
    {
        require(owners[_id] == address(0), "Order already exists");
        require(_baseAddress != _quoteAddress, "Exchanged tokens must be different");
        require(_baseLimit > 0, "Base limit must be positive");
        require(_quoteLimit > 0, "Quote limit must be positive");
        require(_expirationTimestamp > now, "Expiration time must be in future");

        owners[_id] = msg.sender;
        baseAddresses[_id] = _baseAddress;
        quoteAddresses[_id] = _quoteAddress;
        expirationTimestamps[_id] = _expirationTimestamp;
        limits[_id][_baseAddress] = _baseLimit;
        limits[_id][_quoteAddress] = _quoteLimit;
        baseOnlyInvestor[_id] = _baseOnlyInvestor;
        minInvestments[_id][_baseAddress] = _minBaseInvestment;
        minInvestments[_id][_quoteAddress] = _minQuoteInvestment;

        emit OrderCreated(
            _id,
            msg.sender,
            _baseAddress,
            _quoteAddress,
            _baseLimit,
            _quoteLimit,
            _expirationTimestamp
        );
    }

    function deposit(
        bytes32 _id,
        address _token,
        uint _amount
    )
        payable
        external
        nonReentrant
        onlyWhenVaultDefined
    {
        if (_token == address(0)) {
            require(msg.value == _amount, "Payable value should be equals value");
            address(vault).transfer(msg.value);
        } else {
            require(msg.value == 0, "Payable not allowed here");
            uint allowance = IERC20(_token).allowance(msg.sender, address(this));
            require(_amount <= allowance, "Allowance should be not less than amount");
            IERC20(_token).transferFrom(msg.sender, address(vault), _amount);
        }
        _deposit(_id, _token, msg.sender, _amount);
    }

    function cancel(bytes32 _id)
        external
        nonReentrant
        onlyOrderOwner(_id)
        onlyWhenVaultDefined
    {
        require(!isCancelled[_id], "Already cancelled");
        require(!isSwapped[_id], "Already swapped");

        address[2] memory tokens = [baseAddresses[_id], quoteAddresses[_id]];
        for (uint t = 0; t < tokens.length; t++) {
            address token = tokens[t];
            for (uint u = 0; u < investors[_id][token].length; u++) {
                address user = investors[_id][token][u];
                uint userInvestment = investments[_id][token][user];
                vault.withdraw(token, user, userInvestment);
            }
        }

        isCancelled[_id] = true;
        emit Cancel(_id);
    }

    function refund(bytes32 _id, address _token)
        external
        nonReentrant
        onlyInvestor(_id, _token)
        onlyWhenVaultDefined
    {
        require(!isSwapped[_id], "Already swapped");
        address user = msg.sender;
        uint investment = investments[_id][_token][user];
        if (investment > 0) {
            delete investments[_id][_token][user];
        }

        _removeInvestor(investors[_id][_token], user);

        if (investment > 0) {
            raised[_id][_token] = raised[_id][_token].sub(investment);
            vault.withdraw(_token, user, investment);
        }

        emit Refund(_id, _token, user, investment);
    }

    function setVault(Vault _vault) external onlyOwner {
        vault = _vault;
    }

    function createKey(address _owner)
        public
        view
        returns (bytes32 result)
    {
        uint creationTime = now;
        result = 0x0000000000000000000000000000000000000000000000000000000000000000;
        assembly {
            result := or(result, mul(_owner, 0x1000000000000000000000000))
            result := or(result, and(creationTime, 0xffffffffffffffffffffffff))
        }
    }

    function baseLimit(bytes32 _id)
        public
        view
        returns (uint)
    {
        return limits[_id][baseAddresses[_id]];
    }

    function quoteLimit(bytes32 _id)
        public
        view
        returns (uint)
    {
        return limits[_id][quoteAddresses[_id]];
    }

    function baseRaised(bytes32 _id)
        public
        view
        returns (uint)
    {
        return raised[_id][baseAddresses[_id]];
    }

    function quoteRaised(bytes32 _id)
        public
        view
        returns (uint)
    {
        return raised[_id][quoteAddresses[_id]];
    }

    function isBaseFilled(bytes32 _id)
        public
        view
        returns (bool)
    {
        return raised[_id][baseAddresses[_id]] == limits[_id][baseAddresses[_id]];
    }

    function isQuoteFilled(bytes32 _id)
        public
        view
        returns (bool)
    {
        return raised[_id][quoteAddresses[_id]] == limits[_id][quoteAddresses[_id]];
    }

    function baseInvestors(bytes32 _id)
        public
        view
        returns (address[] memory)
    {
        return investors[_id][baseAddresses[_id]];
    }

    function quoteInvestors(bytes32 _id)
        public
        view
        returns (address[] memory)
    {
        return investors[_id][quoteAddresses[_id]];
    }

    function baseUserInvestment(bytes32 _id, address _user)
        public
        view
        returns (uint)
    {
        return investments[_id][baseAddresses[_id]][_user];
    }

    function quoteUserInvestment(bytes32 _id, address _user)
        public
        view
        returns (uint)
    {
        return investments[_id][quoteAddresses[_id]][_user];
    }

    function _swap(bytes32 _id) internal {
        require(!isSwapped[_id], "Already swapped");
        require(!isCancelled[_id], "Already cancelled");
        require(isBaseFilled(_id), "Base tokens not filled");
        require(isQuoteFilled(_id), "Quote tokens not filled");
        require(now <= expirationTimestamps[_id], "Contract expired");

        _distribute(_id, baseAddresses[_id], quoteAddresses[_id]);
        _distribute(_id, quoteAddresses[_id], baseAddresses[_id]);

        isSwapped[_id] = true;
        emit Swap(_id, msg.sender);
    }

    function _distribute(bytes32 _id, address _aSide, address _bSide) internal {
        uint remainder = raised[_id][_bSide];
        for (uint i = 0; i < investors[_id][_aSide].length; i++) {
            address user = investors[_id][_aSide][i];
            uint toPay;
            // last
            if (i + 1 == investors[_id][_aSide].length) {
                toPay = remainder;
            } else {
                uint aSideRaised = raised[_id][_aSide];
                uint userInvestment = investments[_id][_aSide][user];
                uint bSideRaised = raised[_id][_bSide];
                toPay = userInvestment.mul(bSideRaised).div(aSideRaised);
                remainder = remainder.sub(toPay);
            }

            vault.withdraw(_bSide, user, toPay);
            emit SwapSend(_id, _bSide, user, toPay);
        }
    }

    function _removeInvestor(address[] storage _array, address _investor) internal {
        uint idx = _array.length - 1;
        for (uint i = 0; i < _array.length - 1; i++) {
            if (_array[i] == _investor) {
                idx = i;
                break;
            }
        }

        _array[idx] = _array[_array.length - 1];
        delete _array[_array.length - 1];
        _array.length--;
    }

    function _deposit(
        bytes32 _id,
        address _token,
        address _from,
        uint _amount
    ) internal {
        uint amount = _amount;
        require(baseAddresses[_id] == _token || quoteAddresses[_id] == _token, "You can deposit only base or quote currency");
        require(raised[_id][_token] < limits[_id][_token], "Limit already reached");
        require(now <= expirationTimestamps[_id], "Contract expired");
        if (baseAddresses[_id] == _token && baseOnlyInvestor[_id] != address(0)) {
            require(msg.sender == baseOnlyInvestor[_id], "Allowed only for specified address");
        }
        if (limits[_id][_token].sub(raised[_id][_token]) > minInvestments[_id][_token]) {
            require(_amount >= minInvestments[_id][_token], "Should not be less than minimum value");
        }

        if (!_isInvestor(_id, _token, _from)) {
            require(investors[_id][_token].length < MAX_INVESTORS, "Too many investors");
            investors[_id][_token].push(_from);
        }

        uint raisedWithOverflow = raised[_id][_token].add(amount);
        if (raisedWithOverflow > limits[_id][_token]) {
            uint overflow = raisedWithOverflow.sub(limits[_id][_token]);
            vault.withdraw(_token, _from, overflow);
            amount = amount.sub(overflow);
        }

        investments[_id][_token][_from] = investments[_id][_token][_from].add(amount);

        raised[_id][_token] = raised[_id][_token].add(amount);
        emit Deposit(
            _id,
            _token,
            _from,
            amount,
            investments[_id][_token][_from]
        );

        if (isBaseFilled(_id) && isQuoteFilled(_id)) {
            _swap(_id);
        }
    }

    function _isInvestor(
        bytes32 _id,
        address _token,
        address _who
    )
        internal
        view
        returns (bool)
    {
        return investments[_id][_token][_who] > 0;
    }
}
