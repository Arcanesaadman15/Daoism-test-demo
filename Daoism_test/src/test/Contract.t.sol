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

contract ContractTest is DSTest {
    BFactory public bFactory;
    CRPFactory public crpFactory;
    GnosisSafe public safe;
    Cheats internal constant cheats = Cheats(HEVM_ADDRESS);
    address[] public tokenAddr;
    MockERC20 public prime;
    MockERC20 public dai;
    VoterModule public module;
    bytes4 public REMOVEOWNER = bytes4(keccak256(bytes('removeOwner(address,address,uint256)')));
    bytes4 public ADDOWNER = bytes4(keccak256(bytes('addOwnerWithThreshold(address,uint256)')));



    struct PoolParams {
        // Balancer Pool Token (representing shares of the pool)
        string poolTokenSymbol;
        string poolTokenName;
        // Tokens inside the Pool
        address[] constituentTokens;
        uint[] tokenBalances;
        uint[] tokenWeights;
        uint swapFee;
    }

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

    function testExample() public {
        ConfigurableRightsPool pool = Balancer();
        module = new VoterModule(address(safe),address(safe),address(safe),address(pool));
        bytes memory data = abi.encode(
            address(safe),address(safe),address(safe)
        );
        
        address[] memory examples = new address[](4);
        examples[0] = cheats.addr(1);
        examples[1] = cheats.addr(2);
        examples[2] = cheats.addr(3);
        examples[3] = cheats.addr(4);
        safe.setup(examples, 2, cheats.addr(3), data, cheats.addr(3), cheats.addr(4), 1, payable(cheats.addr(6)));

        address own = safe.getOwners()[0];
        assert (own == cheats.addr(1));
        safe.addOwnerWithThreshold(cheats.addr(5), 2);
        assert(safe.isOwner(cheats.addr(5)));
        safe.enableModule(address(module));

        bytes memory command = abi.encodeWithSelector(REMOVEOWNER, cheats.addr(3), cheats.addr(4),2);
         //cheats.prank(cheats.addr(2));
        module.createProposal(command);
        module.vote(0);
        cheats.warp(2 days);
        module.executeProposal(0);
    }

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

    function testBalancer()public {
        ConfigurableRightsPool pool = Balancer();
        uint[] memory num = new uint[](2);
        num[0] = 10000 wei;
        num[0] = 8000 wei;
        pool.setPublicSwap(true);
        dai.mintto(cheats.addr(2));
        prime.mintto(cheats.addr(2));

        cheats.prank(cheats.addr(2));
        pool.joinPool(2000000000, num);
        cheats.stopPrank();
        emit log_uint(IERC20(pool).balanceOf(cheats.addr(2)));
        assert(IERC20(pool).totalSupply()>0);
        assert(IERC20(pool).balanceOf(address(this))>0);
       // pool.transfer(cheats.addr(2), 1000);
        assert(IERC20(pool).balanceOf(cheats.addr(2))>0);
        assert(IERC20(pool).balanceOf(cheats.addr(6))==0);
        assert(IERC20(pool).balanceOf(address(this))>IERC20(pool).balanceOf(cheats.addr(2)));

    }
}
