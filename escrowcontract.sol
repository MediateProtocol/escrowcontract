pragma solidity 0.5.15;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";


contract EscrowService is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum Status {_, CREATED, FUNDED, DISPUTED, RELEASED, MEDIATED, CANCELLED}

    address private _mediationService;

    //This will be in percentage. 200 for 2%
    uint256 private _mediationServiceFee;

    //TODO: add getter and setters
    address private _feeWallet;

    //TODO: add getter and settes
    uint256 private _fee;

    address constant private ETH_ADDRESS = address(
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    );

    mapping(address => bool) private _supportedTokens;

    struct Escrow {
        address creator;
        address depositor;
        address recepient;
        address mediator;
        address beneficiary;
        address token;
        uint256 amount;
        uint256 lastDepositTime;
        uint256 createdTime;
        uint256 mediationFee;
        string extraData;
        string reason;
        Status status;
    }

    mapping (uint256 => Escrow) private _idVsEscrow;

    //TODO: add getter
    uint256 private _totalEscrows;

    event TokenAdded(address token);
    event TokenRemoved(address token);

    event MediationServiceChanged(address mediationService);
    event MeidationServiceFeeChanged(uint256 fee);

    event FeeChanged(uint256 indexed fee);
    event FeeWalletChanged(address indexed feeWallet);

    event EscrowAdded(
        address indexed depositor,
        address indexed recepient,
        address indexed mediator,
        uint256 id,
        address token
    );
    //This event is added to listen for creator
    event EscrowCreated(uint256 id, address indexed creator);

    event Funded(uint256 indexed id);
    event Disputed(uint256 indexed id, address party);
    event Cancelled(uint256 id);
    event Released(uint256 id, address indexed receiver);

    modifier tokenSupported(address token){
        require(_supportedTokens[token], "EscrowService: Token not supported");
        _;
    }

    modifier escrowExist(uint256 id){
        require(
            id != 0 && id <= _totalEscrows,
            "EscroService: Invalid escrow"
        );
        _;
    }

    constructor(
        address mediationService,
        uint256 mediationServiceFee,
        uint256 fee,
        address feeWallet
    )
        public
    {
        require(
            mediationService != address(0),
            "EscrowService: Invalid mediation service!!"
        );

        _mediationService = mediationService;
        _mediationServiceFee = mediationServiceFee;
        _fee = fee;
        _feeWallet = feeWallet;
    }

    /**
    * @dev Returns fee wallet
    */
    function getFeeWallet() external view returns(address){
        return _feeWallet;
    }

    /**
    * @dev Allows owner to set fee wallet
    * @param feeWallet Fee wallet address
    */
    function setFeeWallet(address feeWallet) external onlyOwner {
        require(
            feeWallet == address(0),
            "EscrowService: Invalid fee wallet address"
        );
        _feeWallet = feeWallet;
        emit FeeWalletChanged(_feeWallet);

    }
    
    /**
    @dev Returns platform fee
    */
    function getFee() external view returns(uint256) {
        return _fee;
    }
    
    /**
    * @dev Allows owner to set fee
    * @param fee New fees
    */
    function setFee(uint256 fee) external onlyOwner {
        _fee = fee;
        emit FeeChanged(fee);
    }

    /**
    * @dev Returns total escrows so far
    */
    function getTotalEscrows() external view returns(uint256) {
        return _totalEscrows;
    }
    
    /**
    * @dev Returns mediation service address
    */
    function getMediationService() external view returns(address) {
        return _mediationService;
    }

    /**
    * @dev Allows admin to change mediationService address
    * @param mediationService New mediation service
    */
    function changeMediationService(
        address mediationService
    )
        external
        onlyOwner
    {
        require(
            mediationService != address(0),
            "EscrowService: Invalid mediation service!!"
        );

        _mediationService = mediationService;
        emit MediationServiceChanged(mediationService);
    }

    /**
    * @dev Returns mediation service fee
    */
    function getMediationServiceFee() external view returns(uint256) {
        return _mediationServiceFee;
    }

    /**
    * @dev Allow admin to change mediation service fee
    * @param mediationServiceFee New mediation service fee
    */
    function changeMediationServiceFee(
        uint256 mediationServiceFee
    )
        external
        onlyOwner
    {
        _mediationServiceFee = mediationServiceFee;
        emit MeidationServiceFeeChanged(mediationServiceFee);
    }

    /**
    * @dev Returns whether given token is supported or not
    * @param tokenAddress Token to be checked
    */
    function isTokenSupported(
        address tokenAddress
    )
        external
        view
        returns(bool)
    {
        return _supportedTokens[tokenAddress];
    }

    /**
    * @dev Allows admin to add new supported token
    * @param tokenAddress token address to be added
    */
    function addToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "EscrowService: Invalid address");
        _supportedTokens[tokenAddress] = true;
        emit TokenAdded(tokenAddress);
    }

    /**
    * @dev Allows admin to remove supported token
    * @param tokenAddress Token to be removed
    */
    function removeToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "EscrowService: Invalid address");
        _supportedTokens[tokenAddress] = false;
        emit TokenRemoved(tokenAddress);
    }

    /**
    * @dev Returns Escrow for the given id
    * @param id Id to be fetched
    */
    function getEscrow(uint256 id) external view returns(
        address creator,
        address depositor,
        address recepient,
        address mediator,
        address token,
        uint256 amount,
        uint256 lastDepositTime,
        uint256 mediationFee,
        string memory extraData,
        Status status,
        uint256 createdTime,
        address beneficiary
    )
    {
        Escrow memory escrow = _idVsEscrow[id];
        creator = escrow.creator;
        depositor = escrow.depositor;
        recepient = escrow.recepient;
        mediator = escrow.mediator;
        token = escrow.token;
        amount = escrow.amount;
        lastDepositTime = escrow.lastDepositTime;
        mediationFee = escrow.mediationFee;
        extraData = escrow.extraData;
        status = escrow.status;
        createdTime = escrow.createdTime;
        beneficiary = escrow.beneficiary;

        return(
            creator,
            depositor,
            recepient,
            mediator,
            token,
            amount,
            lastDepositTime,
            mediationFee,
            extraData,
            status,
            createdTime,
            beneficiary
        );
    }


    /**
    * @dev Allows depositor or recepient to release funds to either party
    * @param id id of the escrow
    * @param beneficiary Beneficiary of the release
    */
    function release(
        uint256 id,
        address beneficiary
    )
        external
        escrowExist(id)
    {
        Escrow storage escrow = _idVsEscrow[id];

        require(
            escrow.status == Status.FUNDED,
            "EscrowService: Escrow can not be released"
        );

        require(
            (msg.sender == escrow.depositor && beneficiary == escrow.recepient) ||
            (msg.sender == escrow.recepient && beneficiary == escrow.depositor),
            "EscrowService: Illegal release of funds"
        );

        escrow.status = Status.RELEASED;
        escrow.beneficiary = beneficiary;

        _release(
            escrow.token,
            escrow.amount,
            beneficiary
        );
        emit Released(id, beneficiary);
    }

    /**
    * @dev Allows depositor to deposit funds in the escrow
    * @param id id of the escrow
    */
    function deposit(
        uint256 id
    )
        external
        payable
        escrowExist(id)
    {
        Escrow storage escrow = _idVsEscrow[id];

        require(
            escrow.depositor == address(0) || escrow.depositor == msg.sender,
            "EscrowService: Invalid depositor"
        );

        require(
            escrow.status == Status.CREATED,
            "EscrowService: Not accepting deposit"
        );

        if(escrow.lastDepositTime >= block.timestamp) {
            _deposit(
                escrow.token,
                escrow.amount,
                msg.value
            );
            escrow.status = Status.FUNDED;
            escrow.depositor = msg.sender;
            emit Funded(id);
        }
        else {
            escrow.status = Status.CANCELLED;
            emit Cancelled(id);
        }
    }

    /**
    * @dev allows depositor or recepient to raise dispute
    * @param id id of the escrow
    */
    function raiseDispute(
        uint256 id
    )
        external
        escrowExist(id)
    {
        Escrow storage escrow = _idVsEscrow[id];

        require(
            msg.sender == escrow.depositor ||
            msg.sender == escrow.recepient,
            "EscrowService: Access denied"
        );

        require(
            escrow.status == Status.FUNDED,
            "EscrowService: Escrow can not be disputed"
        );

        escrow.status = Status.DISPUTED;
        emit Disputed(id, msg.sender);
    }

    /**
    * @dev Allows mediator to mediate disputed escrow
    * @param id id of the escrow
    * @param beneficiary to whom escrow will be released
    * @param reason ipfs link to the reason 
    */
    function mediate(
        uint256 id,
        address beneficiary,
        string calldata reason
    )
        external
        escrowExist(id)
    {
        Escrow storage escrow = _idVsEscrow[id];

        require(
            escrow.status == Status.DISPUTED,
            "EscrowService: Escrow not in disputed state"
        );

        require(
            msg.sender == escrow.mediator,
            "EscrowService: Access denied"
        );

        require(
            beneficiary == escrow.depositor ||
            beneficiary == escrow.recepient,
            "EscrowService: Invalid beneficiary"
        );
        uint256 tempAmount = escrow.amount;
        uint256 mediationFee = tempAmount.mul(escrow.mediationFee).div(10000);
        tempAmount = tempAmount.sub(mediationFee);
        escrow.status = Status.MEDIATED;
        escrow.reason = reason;
        escrow.beneficiary = beneficiary;
        
        _release(
            escrow.token,
            mediationFee,
            escrow.mediator
        );

        _release(
            escrow.token,
            tempAmount,
            beneficiary
        );

        emit Released(id, beneficiary);
    }

    /**
    * @dev Add new escrow
    * @param tokenAddress Token to be used for escrow
    * @param recepient Address of the recepient
    * @param depositor Address of the depositor
    * @param mediator Address of the meidator
    * @param amount Amount of escrow
    * @param lastDepositTime Deposit time threshold
    * @param mediationFee Mediation fee in percentage. 100 for 1%
    * @param extraData Extra information, if any
    */
    function addEscrow(
        address tokenAddress,
        address recepient,
        address depositor,
        address mediator,
        uint256 amount,
        uint256 lastDepositTime,
        uint256 mediationFee,
        string memory extraData
    )
        public
        payable
        tokenSupported(tokenAddress)
    {
        require(recepient != address(0), "EscrowService: Invalid recepient");

        _totalEscrows = _totalEscrows.add(1);
        uint256 remValue = _takeFee(
            tokenAddress,
            amount,
            msg.value
        );

        Escrow storage escrow = _idVsEscrow[_totalEscrows];

        //1. Check if creator is depositor
        if (msg.sender == depositor){
            // Make the deposit
            _deposit(
                tokenAddress,
                amount,
                remValue
            );
            escrow.status = Status.FUNDED;
            emit Funded(_totalEscrows);
        }
        else {
            require(lastDepositTime > block.timestamp, "EscrowService: Invalid last deposit time");
            escrow.status = Status.CREATED;
        }
        if (mediator == address(0)) {
            escrow.mediator = _mediationService;
            escrow.mediationFee = _mediationServiceFee;
        }
        else {
            escrow.mediator = mediator;
            escrow.mediationFee = mediationFee;
        }

        escrow.token = tokenAddress;
        escrow.recepient = recepient;
        escrow.depositor = depositor;
        escrow.creator = msg.sender;
        escrow.amount = amount;
        escrow.extraData = extraData;
        escrow.lastDepositTime = lastDepositTime;
        escrow.createdTime = now;

        emit EscrowCreated(_totalEscrows, msg.sender);

        emit EscrowAdded(
            depositor,
            recepient,
            escrow.mediator,
            _totalEscrows,
            tokenAddress
        );

    }

    //Helper method to deposit funds
    function _deposit(
        address token,
        uint256 amount,
        uint256 msgValue
    )
        private
    {
        if (token == ETH_ADDRESS) {
            require(msgValue == amount, "EscrowService: Enough ETH not sent!!");
        }
        else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }


    //Helper method
    function _takeFee(
        address tokenAddress,
        uint256 amount,
        uint256 msgValue
    )
        private
        returns(uint256)
    {
        uint256 remValue = 0;
        uint256 fee = amount.mul(_fee).div(10000);

        if (tokenAddress == ETH_ADDRESS) {
            require(msgValue >= fee, "EscrowService: Enough ETH not sent!!");
            (bool success,) = _feeWallet.call.value(fee)("");
            require(success, "EscrowService: Transfer of fee failed");
            remValue = msgValue.sub(fee);
        }
        else{
            IERC20(tokenAddress).safeTransferFrom(msg.sender, _feeWallet, fee);
        }
        return remValue;
    }

    //Helper method to release funds
    function _release(
        address token,
        uint256 amount,
        address beneficiary
    )
        private
    {
        if (token == ETH_ADDRESS) {
            (bool success,) = beneficiary.call.value(amount)("");
            require(success, "EscrowService: Transfer failed");
        }
        else{
            IERC20(token).safeTransfer(beneficiary, amount);
        }
    }

}
