// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <0.9.0;

import "@gnosis/contracts/core/Module.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title A voting module for gnosis safe 
/// @author S Masud
/// @notice This contract can be used to give tokens holders of a certain balancer pool control of the safe based on their liquidity provided
contract VoterModule is Module{
    address BalancerPool;

    event voteValue(uint value);
    event proposalCreated(address proposedBy, bytes command);
    event proposalExecuted(uint id);


    struct Proposal {
        bytes command;  
        uint voteCount;  
        uint timeProposed;
        bool executed;
    }

    Proposal[] public proposals;

    // Mapping to keep track of which addresses already voted on a proposal
    mapping(uint => mapping(address => bool)) voted;

    constructor(
        address _owner,
        address _avatar,
        address _target,
        address _balancerPool
    ) {
        bytes memory initParams = abi.encode(
            _owner,
            _avatar,
            _target,
            _balancerPool
        );
        setUp(initParams);
    }

    // @dev Initialize function, will be triggered when a new proxy is deployed
    // @param _owner Address of the owner
    // @param _avatar Address of the avatar (e.g. a Safe or Delay Module)
    // @param _target Address that this module will pass transactions to
    function setUp(bytes memory initParams) public override initializer {
    (
        address _owner,
        address _avatar,
        address _target,
        address _balancerPool
    ) = abi.decode(initParams,(address,address,address,address));
        __Ownable_init();
        require(_avatar != address(0), "Avatar can not be zero address");
        require(_target != address(0), "Target can not be zero address");
        require(_balancerPool != address(0), "Target can not be zero address");
        avatar = _avatar;
        target = _target;
        BalancerPool = _balancerPool;
        transferOwnership(_owner);

    }


    /// @notice Get current votes on a proposal 
    /// @dev The Alexandr N. Tetearing algorithm could increase precision
    /// @param proposalId the id number used to retreive the proposal 
    function getVoteCount(uint proposalId)public view returns(uint){
        return proposals[proposalId].voteCount;
    }


    
    /// @notice Get current number of proposal 
    function getProposalCount()public view returns(uint){
        return proposals.length;
    }

    /// @notice Create a proposal to be voted to be executed
    /// @dev The Alexandr N. Tetearing algorithm could increase precision
    /// @param command an abi encoded command for the safe to execute if the proposal passes
    function createProposal(bytes memory command)public{
        require(IERC20(BalancerPool).balanceOf(msg.sender)>0);
        proposals.push(Proposal({
                command: command,
                voteCount: 0,
                timeProposed: block.timestamp,
                executed: false

            }));
            emit proposalCreated(msg.sender,command);
        
    }

    /// @notice Vote on a proposal using the proposalId
    /// @dev The balance of pool tokens for msg.sender is used as their voting weight 
    /// @param proposalId the id number used to retreive the proposal 
    function vote(uint proposalId)public{
        require(IERC20(BalancerPool).balanceOf(msg.sender)>0);
        Proposal storage currentProposal =  proposals[proposalId];
        require(!voted[proposalId][msg.sender], "Already Voted");
        currentProposal.voteCount += IERC20(BalancerPool).balanceOf(msg.sender);
        voted[proposalId][msg.sender] = true;
        emit voteValue(IERC20(BalancerPool).balanceOf(msg.sender));

    }

    /// @notice Execuded a proposal using the proposalId
    /// @dev Proposal must be executed in betweeen half a day and 2 weeks of being created
    /// @param proposalId the id number used to retreive the proposal 
    function executeProposal(uint proposalId)public{
        require(IERC20(BalancerPool).balanceOf(msg.sender)>0);
        Proposal storage currentProposal =  proposals[proposalId];
        require(currentProposal.timeProposed + 0.5 days < block.timestamp, "1 day needs to pass");
        require(currentProposal.timeProposed + 2 weeks > block.timestamp, "Execution window elapsed");
        require(currentProposal.voteCount > 2000000000, "Vote threshold not reached");
        require(!currentProposal.executed, "Already executed");
        (bool success,) = avatar.call(currentProposal.command);
        require(success,"tx failed");
        currentProposal.executed = true;
        emit proposalExecuted(proposalId);

    }


}

