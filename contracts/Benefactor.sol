pragma solidity >=0.4.21 <0.7.0;

contract Benefactor {
    struct Sub {
        uint256 subStart; //timestamp of start of subscription
        uint64 period; //period of subscription
    }

    address private _owner; //contract owner that collects subscription fees
    mapping(address => Sub) private _currSubs; //current subs mapped to period of subscription and timestamp of start of subscription
    mapping(uint256 => uint256) unitProfit; //mapping of subscription earnings per unit of time in subscription
    uint256 private _subPrice; //subscription price
    uint256 _withdrawStamp; //last timestamp owner withdrew earnings
    uint256 _subUnit; //subscription charge unit of time
    
    constructor(uint256 subPrice, uint256 subUnit) public {
        _owner = msg.sender;
        _subPrice = subPrice;
        _subUnit = subUnit;
        _withdrawStamp = block.timestamp;
    }
    
    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }

    function startSubscription(uint256 amount, uint64 period) payable external {
        require(msg.value == amount);
        require(amount == _subPrice*period);
        _currSubs[msg.sender].subStart = block.timestamp;
        _currSubs[msg.sender].period = period;
        for(uint i = 1; i <= period; i++) {
            unitProfit[(i * block.timestamp) / _subUnit] += _subPrice; //add subscription fees for each unit of time the user will be subbed for
        }
    }

    function cancelSubscription() external {
        require((_currSubs[msg.sender].period*_subUnit + _currSubs[msg.sender].subStart - block.timestamp) > _subUnit);
        uint256 tokenRet = (_currSubs[msg.sender].period*_subUnit + _currSubs[msg.sender].subStart - block.timestamp) / _subUnit; //get number of subscription units left before subscription ends
        for(uint i = _currSubs[msg.sender].period - tokenRet; i <= _currSubs[msg.sender].period; i++) {
            unitProfit[(i * _currSubs[msg.sender].subStart) / _subUnit] -= _subPrice; //remove refunded subscription fees for each unit of time left
        }
        delete _currSubs[msg.sender];
        msg.sender.transfer(_subPrice*tokenRet); //refund whats left of subscription
    }
    
    function getEtherBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function checkSubscription(address account) external view returns(uint256, uint64) {
        return (_currSubs[account].subStart, _currSubs[account].period);
    }

    function checkProfits(uint256 currentTimestamp) external view returns(uint256) {
        uint256 finPeriod = ((block.timestamp - _withdrawStamp) / _subUnit);
        uint256 totalWithdrawal = 0;
        for(uint i = 1; i <= finPeriod; i++) {
            totalWithdrawal += unitProfit[(i * _withdrawStamp) / _subUnit];
        }
        return totalWithdrawal;
    }

    function ownerWithdrawal() external onlyOwner {
        require((block.timestamp - _withdrawStamp) >= _subUnit);
        uint256 finPeriod = ((block.timestamp - _withdrawStamp) / _subUnit); //get period between last withdrawal and now
        uint256 totalWithdrawal = 0;
        for(uint i = 1; i <= finPeriod; i++) {
            totalWithdrawal += unitProfit[(i * _withdrawStamp) / _subUnit];
            delete unitProfit[(i * _withdrawStamp) / _subUnit];
        }
        msg.sender.transfer(totalWithdrawal);
        _withdrawStamp = block.timestamp - (block.timestamp % _subUnit); //update withdraw timestamp with current time, but adjust so we don't skip a unit of time for next withdrawal
    }
}