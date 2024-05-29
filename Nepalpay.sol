// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/access/Ownable.sol";
import "./NepalPayToken.sol"; // Ensure this path is correct based on your directory structure

/**
 * @title NepalPay
 * @dev Main contract for NepalPay application
 */
contract NepalPay is Ownable {
    NepalPayToken public token;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isModerator;
    mapping(address => uint256) public balance;
    mapping(address => uint256) public debt;
    mapping(address => uint256) public collateral;
    mapping(address => string) private passwords;
    mapping(address => string) public usernameOf;
    mapping(string => address) public addressOfUsername;
    mapping(address => string) public fullName;
    mapping(address => string) public contactEmail;
    mapping(address => mapping(address => bool)) private allowedAccess; // Mapping to store access permissions for full name and contact email
    mapping(address => uint256) public smallPaymentsCounter;
    mapping(address => uint256) public pendingTransactions;
    mapping(address => mapping(bytes32 => uint256)) public crowdfundingCampaigns;
    mapping(address => mapping(bytes32 => ScheduledPayment)) public scheduledPayments;
    mapping(address => string) public userRoles; // Mapping to store user roles based on username
    mapping(string => bool) private usernameReserved; // Mapping to store reserved usernames
    mapping(address => string) public countryOf; // Mapping to store user's country location
    mapping(address => bool) public canReceiveInternationalPayments;
    mapping(address => bool) public canSendInternationalPayments;

    struct ScheduledPayment {
        uint256 amount;
        uint256 timestamp;
        bool active;
    }

    uint256 public smallPaymentsLimit = 50; // 50 small payments allowed per day
    uint256 public smallPaymentAmount = 100; // Maximum amount considered as a small payment
    uint256 public transactionFeePercentage = 1; // 1% transaction fee for developer

    uint256 public interestRate = 5; // 5% annual interest rate
    uint256 public loanDuration = 30 days; // Loan duration is 30 days
    uint256 public pendingTransactionDuration = 30 minutes; // Pending transaction duration is 30 minutes

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event ModeratorAdded(address indexed moderator);
    event ModeratorRemoved(address indexed moderator);
    event TokensDeposited(address indexed sender, uint256 amount);
    event TokensWithdrawn(address indexed recipient, uint256 amount);
    event PriceUpdated(uint256 newPrice);
    event DebtUpdated(address indexed user, uint256 amount);
    event CollateralAdded(address indexed user, uint256 amount);
    event LoanTaken(address indexed borrower, uint256 amount);
    event LoanRepaid(address indexed borrower, uint256 amount);
    event TipsSent(address indexed sender, address indexed recipient, uint256 amount, string description);
    event BusinessPayment(address indexed sender, string indexed recipientUsername, uint256 amount, string description);
    event DeveloperFee(address indexed developer, uint256 amount);
    event UsernameSet(address indexed user, string username, string role);
    event FullNameSet(address indexed user, string fullName);
    event ContactEmailSet(address indexed user, string contactEmail);
    event AccessGranted(address indexed owner, address indexed user);
    event AccessRevoked(address indexed owner, address indexed user);
    event UsernameModified(address indexed owner, address indexed user, string newUsername);
    event FullNameModified(address indexed owner, address indexed user, string newFullName);
    event ContactEmailModified(address indexed owner, address indexed user, string newContactEmail);
    event ModeratorAccessGranted(address indexed owner, address indexed moderator);
    event ModeratorAccessRevoked(address indexed owner, address indexed moderator);
    event TransactionPending(address indexed user, uint256 amount, string description);
    event TransactionCompleted(address indexed user, uint256 amount, string description);
    event TransactionCancelled(address indexed user, uint256 amount, string description);
    event PendingTransactionDurationUpdated(uint256 newDuration);
    event CampaignStarted(address indexed campaignCreator, bytes32 indexed campaignId, uint256 targetAmount, string description);
    event ContributionMade(address indexed contributor, bytes32 indexed campaignId, uint256 amount);
    event ScheduledPaymentSet(address indexed user, uint256 amount, uint256 timestamp);
    event ScheduledPaymentModified(address indexed user, uint256 amount, uint256 timestamp);
    event ScheduledPaymentCancelled(address indexed user);
    event TokensSent(address indexed sender, address indexed recipient, uint256 amount, string description);

    constructor(address _tokenAddress) {
        token = NepalPayToken(_tokenAddress);
        isAdmin[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Only admin can call this function");
        _;
    }

    modifier onlyAdminOrModerator() {
        require(isAdmin[msg.sender] || isModerator[msg.sender], "Caller is not admin or moderator");
        _;
    }

    /**
     * @dev Function to deposit tokens into the contract.
     * @param _amount The amount of tokens to deposit.
     */
    function depositTokens(uint256 _amount) external {
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        token.transferFrom(msg.sender, address(this), _amount);
        balance[msg.sender] += _amount;
        emit TokensDeposited(msg.sender, _amount);
    }

    /**
     * @dev Function to withdraw tokens from the contract.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawTokens(uint256 _amount) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        token.transfer(msg.sender, _amount);
        balance[msg.sender] -= _amount;
        emit TokensWithdrawn(msg.sender, _amount);
    }

    // Function to send tokens with description
    function sendTokens(address _recipient, uint256 _amount, string memory _description) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        balance[msg.sender] -= _amount;
        balance[_recipient] += _amount;
        emit TokensSent(msg.sender, _recipient, _amount, _description);
    }

    // Function to set username
    function setUsername(string memory _username, string memory _role, string memory _country) external {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(!usernameReserved[_username], "Username is already reserved");
        require(addressOfUsername[_username] == address(0), "Username already exists");
        usernameOf[msg.sender] = _username;
        addressOfUsername[_username] = msg.sender;
        userRoles[msg.sender] = _role;
        countryOf[msg.sender] = _country;
        emit UsernameSet(msg.sender, _username, _role);
    }

    // Function to reserve a username
    function reserveUsername(string memory _username) external onlyAdminOrModerator {
        require(bytes(_username).length > 0, "Username cannot be empty");
        usernameReserved[_username] = true;
    }

    // Function to modify a username
    function modifyUsername(address _user, string memory _newUsername, string memory _newRole) external onlyOwner {
        require(bytes(_newUsername).length > 0, "Username cannot be empty");
        require(!usernameReserved[_newUsername], "Username is already reserved");
        require(addressOfUsername[_newUsername] == address(0), "Username already exists");
        string memory oldUsername = usernameOf[_user];
        usernameReserved[oldUsername] = false;
        usernameOf[_user] = _newUsername;
        addressOfUsername[_newUsername] = _user;
        userRoles[_user] = _newRole;
        emit UsernameModified(msg.sender, _user, _newUsername);
    }

    // Function to set international payment permissions
    function setInternationalPaymentPermissions(address _user, bool _canReceive, bool _canSend) external onlyOwner {
        canReceiveInternationalPayments[_user] = _canReceive;
        canSendInternationalPayments[_user] = _canSend;
    }

    // Function to send tokens with international payment permissions
    function sendTokensWithPermissions(address _recipient, uint256 _amount, string memory _description) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");

        if (!canSendInternationalPayments[msg.sender]) {
            // Check if sender is allowed to make international payments
            string memory senderCountry = countryOf[msg.sender];
            string memory recipientCountry = countryOf[_recipient];
            require(keccak256(abi.encodePacked(senderCountry)) == keccak256(abi.encodePacked("Nepal")), "Sender is not allowed to make international payments");
            require(keccak256(abi.encodePacked(recipientCountry)) != keccak256(abi.encodePacked("Nepal")), "Recipient is from Nepal and cannot receive international payments");
        }

        token.transfer(_recipient, _amount);
        emit TokensSent(msg.sender, _recipient, _amount, _description);
    }

    // Function to deposit collateral
    function addCollateral(uint256 _amount) external {
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        token.transferFrom(msg.sender, address(this), _amount);
        collateral[msg.sender] += _amount;
        emit CollateralAdded(msg.sender, _amount);
    }

    // Function to take a loan
    function takeLoan(uint256 _amount) external {
        require(collateral[msg.sender] >= _amount, "Insufficient collateral");
        require(debt[msg.sender] == 0, "User already has an outstanding loan");

        uint256 interest = (_amount * interestRate * loanDuration) / (100 * 365 days);
        uint256 totalLoanAmount = _amount + interest;

        require(balance[msg.sender] >= totalLoanAmount, "Insufficient balance in contract");

        token.transfer(msg.sender, _amount);
        debt[msg.sender] = totalLoanAmount;

        emit LoanTaken(msg.sender, _amount);
    }

    // Function to repay a loan
    function repayLoan(uint256 _amount) external {
        require(debt[msg.sender] > 0, "User does not have an outstanding loan");
        require(balance[msg.sender] >= _amount, "Insufficient balance");

        token.transferFrom(msg.sender, address(this), _amount);
        debt[msg.sender] -= _amount;

        emit LoanRepaid(msg.sender, _amount);
    }

    // Function to send tips
    function sendTips(address _recipient, uint256 _amount, string memory _description) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        token.transfer(_recipient, _amount);
        emit TipsSent(msg.sender, _recipient, _amount, _description);
    }

    // Function to make a business payment
    function makeBusinessPayment(string memory _recipientUsername, uint256 _amount, string memory _description) external {
        require(bytes(_recipientUsername).length > 0, "Recipient username cannot be empty");
        address _recipient = addressOfUsername[_recipientUsername];
        require(_recipient != address(0), "Recipient username does not exist");
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        token.transfer(_recipient, _amount);
        emit BusinessPayment(msg.sender, _recipientUsername, _amount, _description);
    }

    // Function to start a crowdfunding campaign
    function startCampaign(bytes32 _campaignId, uint256 _targetAmount, string memory _description) external {
        require(_targetAmount > 0, "Target amount must be greater than zero");
        crowdfundingCampaigns[msg.sender][_campaignId] = _targetAmount;
        emit CampaignStarted(msg.sender, _campaignId, _targetAmount, _description);
    }

    // Function to contribute to a crowdfunding campaign
    function contribute(bytes32 _campaignId, uint256 _amount) external {
        require(crowdfundingCampaigns[msg.sender][_campaignId] > 0, "Campaign does not exist");
        require(_amount > 0, "Contribution amount must be greater than zero");
        token.transferFrom(msg.sender, address(this), _amount);
        crowdfundingCampaigns[msg.sender][_campaignId] -= _amount;
        emit ContributionMade(msg.sender, _campaignId, _amount);
    }

    // Function to set a scheduled payment
    function setScheduledPayment(bytes32 _paymentId, uint256 _amount, uint256 _timestamp) external {
        require(_amount > 0, "Payment amount must be greater than zero");
        require(_timestamp > block.timestamp, "Timestamp must be in the future");
        scheduledPayments[msg.sender][_paymentId] = ScheduledPayment(_amount, _timestamp, true);
        emit ScheduledPaymentSet(msg.sender, _amount, _timestamp);
    }

    // Function to modify a scheduled payment
    function modifyScheduledPayment(bytes32 _paymentId, uint256 _amount, uint256 _timestamp) external {
        require(scheduledPayments[msg.sender][_paymentId].active, "Scheduled payment does not exist");
        require(_amount > 0, "Payment amount must be greater than zero");
        require(_timestamp > block.timestamp, "Timestamp must be in the future");
        scheduledPayments[msg.sender][_paymentId].amount = _amount;
        scheduledPayments[msg.sender][_paymentId].timestamp = _timestamp;
        emit ScheduledPaymentModified(msg.sender, _amount, _timestamp);
    }

    // Function to cancel a scheduled payment
    function cancelScheduledPayment(bytes32 _paymentId) external {
        require(scheduledPayments[msg.sender][_paymentId].active, "Scheduled payment does not exist");
        scheduledPayments[msg.sender][_paymentId].active = false;
        emit ScheduledPaymentCancelled(msg.sender);
    }
}
