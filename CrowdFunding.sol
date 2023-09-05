// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

contract CrowdFunding {

    event CampaignCreated(uint indexed campaignId, address indexed campaignOwner, string description, uint minimumContribution);

    event RequestCreated(uint indexed requestId, uint indexed campaignId, uint value, address indexed recipient, string description);

    address public admin;
    
    struct Campaign {
        uint campaignId;
        uint minimumContribution;
        uint totalContributers;
        uint[] campaignRequests;
        address[] contributers;
        string description;
        address campaignOwner;
    }
    uint public campaignCount;

    mapping(uint => Campaign) public campaigns;

    /// campaign id -> user address -> amount
    mapping(uint => mapping(address => uint)) public contributions;

    struct Request {
        uint requestId;
        uint value;
        uint approvalCount;
        string description;
        address recipient;
        bool complete;
    }
    uint public requestCount;

    mapping(uint => Request) public request;

    enum Status {UNAPPROVED, APPROVED, REJECTED}

    /// request id -> user address -> approved / rejected / unapproved
    mapping(uint => mapping(address => Status)) public approvals;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Insufficient Access");
        _;
    }

    modifier onlyCampaignOwner(uint _campaignId) {
        require(msg.sender == campaigns[_campaignId].campaignOwner, "Insufficient Access");
        _;
    }

    modifier onlyValidCampaign(uint _campaignId) {
        require(_campaignId != 0 && _campaignId == campaigns[_campaignId].campaignId, "Invalid Campaign");
        _;
    }

    modifier onlyValidRequest(uint _requestId) {
        require(_requestId != 0 && _requestId == request[_requestId].requestId && !request[_requestId].complete, "Invalid Request");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function createCampaign(uint _minimumContribution, string memory _description) external {

        require(_minimumContribution > 0, "Minimum Contribution must be greater than 0.");

        campaignCount++;

        campaigns[campaignCount].campaignId = campaignCount;
        campaigns[campaignCount].minimumContribution = _minimumContribution;
        campaigns[campaignCount].description = _description;
        campaigns[campaignCount].campaignOwner = msg.sender;
        
        emit CampaignCreated(campaignCount, msg.sender, _description, _minimumContribution);

    }

    function contribute(uint _campaignId) external payable onlyValidCampaign(_campaignId) {

        require(msg.value + contributions[_campaignId][msg.sender] >= campaigns[_campaignId].minimumContribution, "Amount cannot be lesser than minimum contribution.");
        
        if(contributions[_campaignId][msg.sender] == 0) {
            campaigns[_campaignId].contributers.push(msg.sender);
            campaigns[_campaignId].totalContributers++;
        } 
        contributions[_campaignId][msg.sender] += msg.value;

    }

    function createRequest(uint _campaignId, uint _value, string memory _description, address _recipient) external onlyValidCampaign(_campaignId) onlyCampaignOwner(_campaignId) {
        
        require(_value > 0, "Value must be greater than 0.");
        require(_recipient != address(0), "Invalid Recipient Address");
        
        requestCount++;

        request[requestCount] = Request({
            requestId : requestCount,
            value : _value,
            approvalCount : 0,
            description : _description,
            recipient : _recipient,
            complete : false
        });

        campaigns[_campaignId].campaignRequests.push(requestCount);
        
        emit RequestCreated(requestCount, _campaignId, _value, _recipient, _description);

    }

    function updateRequest(uint _requestId, uint _campaignId, bool _status) external onlyValidRequest(_requestId) onlyValidCampaign(_campaignId) {

        require(contributions[_campaignId][msg.sender] > 0, "You are not allowed to vote this request");
        require(approvals[_requestId][msg.sender] == Status.UNAPPROVED, "Cannot vote multiple times");

        approvals[_requestId][msg.sender] = _status ? Status.APPROVED : Status.REJECTED;
        if(_status)    request[_requestId].approvalCount++;
        
    }

    function finalizeRequest(uint _requestId, uint _campaignId) external onlyValidRequest(_requestId) onlyValidCampaign(_campaignId) onlyCampaignOwner(_campaignId) {

        require(request[_requestId].approvalCount > (campaigns[_campaignId].totalContributers / 2), "More than 50% approvals required.");

        payable(request[_requestId].recipient).transfer(request[_requestId].value);
        request[_requestId].complete = true;

    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function getCampaignRequests(uint _campaignId) external view onlyValidCampaign(_campaignId) returns (uint[] memory requests) {
        return campaigns[_campaignId].campaignRequests;
    }

    function getCampaignContributers(uint _campaignId) external view onlyValidCampaign(_campaignId) returns (address[] memory contributers) {
        return campaigns[_campaignId].contributers;
    }

}