pragma solidity >=0.4.21 <0.7.0;

contract Benefactor {
    struct Sub {
        uint256 subStart; //timestamp of start of subscription in unit of time
        uint256 subEnd; //timestamp of end of subscription in unit of time
    }

    address private _owner; //contract owner that collects subscription fees
    mapping(address => Sub) private _currSubs; //current subs mapped to period of subscription and timestamp of start of subscription
    mapping(uint256 => uint256) unitProfit; //mapping of subscription earnings per unit of time in subscription
    uint256 private _subPrice; //subscription price
    uint256 _withdrawStamp; //last timestamp owner withdrew earnings in unit of time
    uint256 _subUnit; //subscription charge unit of time
    
    constructor(uint256 subPrice, uint256 subUnit) public {
        _owner = msg.sender;
        _subPrice = subPrice;
        _subUnit = subUnit;
        _withdrawStamp = block.timestamp / _subUnit;
    }
    
    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }

    function startSubscription(uint256 amount, uint256 period) payable external {
        require(msg.value == amount);
        require(amount == _subPrice*period);
        uint256 currTimeUnit = block.timestamp / _subUnit;
        uint256 finalTimeUnit = currTimeUnit + period*_subUnit;
        _currSubs[msg.sender].subStart = currTimeUnit;
        _currSubs[msg.sender].subEnd = finalTimeUnit;
        for(uint256 i = currTimeUnit; i <= finalTimeUnit; i += _subUnit) {
            unitProfit[i] += _subPrice; //add subscription fees for each unit of time the user will be subbed for
        }
    }

    function cancelSubscription() external {
        require((_currSubs[msg.sender].subEnd - (block.timestamp / _subUnit)) > 1);
        uint256 currTimeUnit = block.timestamp / _subUnit;
        uint256 tokenRet = _currSubs[msg.sender].subEnd - currTimeUnit; //get number of subscription units left before subscription ends
        for(uint256 i = currTimeUnit; i <= _currSubs[msg.sender].subEnd; i += _subUnit) {
            unitProfit[i] -= _subPrice; //remove refunded subscription fees for each unit of time left
        }
        delete _currSubs[msg.sender];
        msg.sender.transfer(_subPrice*tokenRet); //refund whats left of subscription
    }
    
    function getEtherBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function checkSubscription(address account) external view returns(uint256, uint256) {
        return (_currSubs[account].subStart, _currSubs[account].subEnd);
    }

    function checkProfits(uint256 currentTimestamp) external view returns(uint256) {
        uint256 currTimeUnit = currentTimestamp / _subUnit;
        uint256 totalWithdrawal = 0;
        for(uint256 i = _withdrawStamp; i <= currTimeUnit; i += _subUnit) {
            totalWithdrawal += unitProfit[i];
        }
        return totalWithdrawal;
    }

    function ownerWithdrawal() external onlyOwner {
        require(((block.timestamp / _subUnit) - _withdrawStamp) >= 1);
        uint256 currTimeUnit = block.timestamp / _subUnit;
        uint256 totalWithdrawal = 0;
        for(uint256 i = _withdrawStamp; i <= currTimeUnit; i += _subUnit) {
            totalWithdrawal += unitProfit[i];
            delete unitProfit[i];
        }
        msg.sender.transfer(totalWithdrawal);
        _withdrawStamp = currTimeUnit; //update withdraw timestamp with current time in units used
    }
}