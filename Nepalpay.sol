// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NepalPayToken is ERC20Burnable {
    constructor() ERC20("NepalPay Token", "NPT") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

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

    function addAdmin(address _admin) external onlyOwner {
        isAdmin[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        isAdmin[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function addModerator(address _moderator) external onlyOwner {
        isModerator[_moderator] = true;
        emit ModeratorAdded(_moderator);
    }

    function removeModerator(address _moderator) external onlyOwner {
        isModerator[_moderator] = false;
        emit ModeratorRemoved(_moderator);
    }

    function depositTokens(uint256 _amount) external {
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        token.transferFrom(msg.sender, address(this), _amount);
        balance[msg.sender] += _amount;
        emit TokensDeposited(msg.sender, _amount);
    }

    function withdrawTokens(uint256 _amount) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        token.transfer(msg.sender, _amount);
        balance[msg.sender] -= _amount;
        emit TokensWithdrawn(msg.sender, _amount);
    }

    function updatePrice(uint256 _newPrice) external onlyAdmin {
        // Example of integrating with an external oracle
        // In a real-world scenario, you would use a decentralized oracle or trusted data provider
        emit PriceUpdated(_newPrice);
    }

    function updateDebt(address _user, uint256 _amount) external onlyAdmin {
        debt[_user] = _amount;
        emit DebtUpdated(_user, _amount);
    }

    function getUserDebt(address _user) external view returns (uint256) {
        return debt[_user];
    }

    function addCollateral(uint256 _amount) external {
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        token.transferFrom(msg.sender, address(this), _amount);
        collateral[msg.sender] += _amount;
        emit CollateralAdded(msg.sender, _amount);
    }

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

    function repayLoan(uint256 _amount) external {
        require(debt[msg.sender] > 0, "User does not have an outstanding loan");
        require(balance[msg.sender] >= _amount, "Insufficient balance");

        token.transferFrom(msg.sender, address(this), _amount);
        debt[msg.sender] -= _amount;

        emit LoanRepaid(msg.sender, _amount);
    }

    function sendTips(address _recipient, uint256 _amount, string memory _description) external {
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        token.transfer(_recipient, _amount);
        emit TipsSent(msg.sender, _recipient, _amount, _description);
    }

    function makeBusinessPayment(string memory _recipientUsername, uint256 _amount, string memory _description) external {
        require(bytes(_recipientUsername).length > 0, "Recipient username cannot be empty");
        address _recipient = addressOfUsername[_recipientUsername];
        require(_recipient != address(0), "Recipient username does not exist");
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        token.transfer(_recipient, _amount);
        emit BusinessPayment(msg.sender, _recipientUsername, _amount, _description);
    }

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

    function reserveUsername(string memory _username) external onlyAdminOrModerator {
        require(bytes(_username).length > 0, "Username cannot be empty");
        usernameReserved[_username] = true;
    }

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

    function setInternationalPaymentPermissions(address _user, bool _canReceive, bool _canSend) external onlyOwner {
        canReceiveInternationalPayments[_user] = _canReceive;
        canSendInternationalPayments[_user] = _canSend;
    }

    function sendTokens(address _recipient, uint256 _amount, string memory _description) external {
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
}

