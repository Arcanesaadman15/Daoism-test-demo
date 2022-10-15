// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../balancer_contracts/BFactory.sol";
import "../balancer_contracts/CRPFactory.sol";
import "../GnosisSafe.sol";
import "../VoterModule.sol";
import "./utils/Cheats.sol";
import "./Mocks/MockERC20.sol";
import "../balancer_contracts/ConfigurableRightsPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HappyPathSimulation is DSTest {
    //Set up of contract instances for the simulation
    BFactory public bFactory;
    CRPFactory public crpFactory;
    GnosisSafe public safe;
    Cheats internal constant cheats = Cheats(HEVM_ADDRESS);
    address[] public tokenAddr;
    MockERC20 public prime;
    MockERC20 public dai;
    VoterModule public module;
    bytes4 private constant REMOVEOWNER = bytes4(keccak256(bytes('removeOwner(address,address,uint256)')));
    bytes4 private constant ADDOWNER = bytes4(keccak256(bytes('addOwnerWithThreshold(address,uint256)')));

    // Pool params struct needed as initializing parameter for a balancer pool
    struct PoolParams {
        string poolTokenSymbol;
        string poolTokenName;
        address[] constituentTokens;
        uint[] tokenBalances;
        uint[] tokenWeights;
        uint swapFee;
    }

    // Pool params struct needed as initializing parameter for a balancer pool
    struct Rights {
        bool canPauseSwapping;
        bool canChangeSwapFee;
        bool canChangeWeights;
        bool canAddRemoveTokens;
        bool canWhitelistLPs;
    }
      
    function setUp() public {
        safe = new GnosisSafe();
        bFactory = new BFactory();
        crpFactory = new CRPFactory();
        dai = new MockERC20();
        prime = new MockERC20();
    }
    
    // The following funtion creates and configures the setting of a balancer pool returing a configureablerightspool object for use in the testhappypathsimulation() funtion
    function Balancer() public returns(ConfigurableRightsPool){
        uint256 swapfee = 10**15;
        address[] memory arr = new address[](2);
        arr[0] = address(dai);
        arr[1] = address(prime);
        uint[] memory start = new uint[](2);
        start[0] = 5 wei;
        start[1] = 5 wei;
        uint[] memory end = new uint[](2);
        end[0] = 10000 wei;
        end[1] = 8000 wei;
        ConfigurableRightsPool.PoolParams memory Pparams = ConfigurableRightsPool.PoolParams("xyz","123",arr,start,end,swapfee);
        RightsManager.Rights memory permissions = RightsManager.Rights(true,true,true,true,true,false);
        ConfigurableRightsPool pool = crpFactory.newCrp(address(bFactory), Pparams, permissions);
        crpFactory.newCrp(address(bFactory), Pparams, permissions);
        dai.approve(address(pool),type(uint128).max);
        prime.approve(address(pool),type(uint128).max);
        pool.createPool(1000*10**18, 10, 10);
        return pool;
    }


    function testhappypathsimulation()public{
        ConfigurableRightsPool pool = Balancer();
        module = new VoterModule(address(safe),address(safe),address(safe),address(pool)); // Initiate voter module

        // Check that addresses 1 2 and 3 do not have any pool tokens
        assert(IERC20(pool).balanceOf(cheats.addr(1))==0);
        assert(IERC20(pool).balanceOf(cheats.addr(2))==0);
        assert(IERC20(pool).balanceOf(cheats.addr(3))==0);


        uint[] memory num = new uint[](2);
        num[0] = 10000 wei;
        num[0] = 8000 wei;
        pool.setPublicSwap(true);

        // Mint mock erc20 tokens to addresses 1 2 3 and poin the balancer pool
        dai.mintto(cheats.addr(1));
        prime.mintto(cheats.addr(1));
        dai.mintto(cheats.addr(2));
        prime.mintto(cheats.addr(2));
        dai.mintto(cheats.addr(3));
        prime.mintto(cheats.addr(3));
        cheats.prank(cheats.addr(1));
        pool.joinPool(1000000000, num);
        cheats.prank(cheats.addr(2));
        pool.joinPool(2000000000, num);
        cheats.prank(cheats.addr(3));
        pool.joinPool(3000000000, num);

        // Check if the addresses now have pool tokens 
        assert(IERC20(pool).balanceOf(cheats.addr(1))>0);
        assert(IERC20(pool).balanceOf(cheats.addr(2))>0);
        assert(IERC20(pool).balanceOf(cheats.addr(3))>0);


        // Set up gnosis safe using dummy parameters and enable the voter module.
        address[] memory examples = new address[](4);
        bytes memory data = abi.encode(
            address(safe),address(safe),address(safe)
        );
        examples[0] = cheats.addr(4);
        examples[1] = cheats.addr(5);
        examples[2] = cheats.addr(6);
        examples[3] = cheats.addr(7);
        safe.setup(examples, 2, cheats.addr(4), data, cheats.addr(4), cheats.addr(5), 1, payable(cheats.addr(6)));
        safe.enableModule(address(module));


        assert(!safe.isOwner(cheats.addr(8))); // Check address 8 is not owner 
        bytes memory command1 = abi.encodeWithSelector(ADDOWNER, cheats.addr(8),2);
        cheats.prank(cheats.addr(1));
        module.createProposal(command1);// Add proposal to add address 8 as an owner 
        cheats.prank(cheats.addr(1));
        module.vote(0);// Address 1 votes to approve the proposal 
        cheats.prank(cheats.addr(2));
        module.vote(0);// Address 2 votes to approve the proposal 
        cheats.warp(2 days);
        cheats.prank(cheats.addr(3));
        module.executeProposal(0);// Address 3 votes to approve the proposal 
        assert(safe.isOwner(cheats.addr(8)));
        
        

        assert(safe.isOwner(cheats.addr(5)));// Check address 5 is owner
        bytes memory command2 = abi.encodeWithSelector(REMOVEOWNER, cheats.addr(4),cheats.addr(5),2);
        cheats.prank(cheats.addr(3));
        module.createProposal(command2); // Add proposal to remove address 5 as an owner 
        cheats.prank(cheats.addr(3)); 
        module.vote(1);// Address 3 votes to approve the proposal 
        cheats.warp(1 weeks);
        cheats.prank(cheats.addr(1));
        module.executeProposal(1);// Address 1 executes proposal
        assert(!safe.isOwner(cheats.addr(5))); // Check address 5 is no longer
        

    }

}