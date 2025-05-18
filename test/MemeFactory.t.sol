// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 引入 Foundry 的测试库
import "../lib/forge-std/src/Test.sol";
// 引入 MemeFactory 和 MemeToken 合约
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

// MemeFactory 的测试合约
contract MemeFactoryTest is Test {
    // 工厂合约实例
    MemeFactory public factory;
    // 平台方、发行者、铸币者都用 Receiver 合约，能接收 ETH
    Receiver public factoryOwner;
    Receiver public creator;
    Receiver public minter;
    // 初始余额
    uint256 public constant INITIAL_BALANCE = 100 ether;

    // 每个测试前都会执行 setUp，初始化环境
    function setUp() public {
        // 部署能接收 ETH 的 Receiver 合约作为各角色
        factoryOwner = new Receiver();
        creator = new Receiver();
        minter = new Receiver();
        // 给平台方和测试合约本身分配初始余额
        vm.deal(address(factoryOwner), INITIAL_BALANCE);
        vm.deal(address(this), INITIAL_BALANCE);
        // 用平台方身份部署 MemeFactory
        vm.prank(address(factoryOwner));
        factory = new MemeFactory();
    }

    // 测试 MemeToken 的部署
    function testDeployInscription() public {
        // 给发行者分配余额
        vm.deal(address(creator), INITIAL_BALANCE);
        // 用发行者身份部署 MemeToken
        vm.prank(address(creator));
        address token = factory.deployInscription("TEST", 1000, 10, 1 ether);
        MemeToken memeToken = MemeToken(token);
        // 校验 MemeToken 的参数
        assertEq(memeToken.symbol(), "TEST");
        assertEq(memeToken.totalSupplyCap(), 1000);
        assertEq(memeToken.perMint(), 10);
        assertEq(memeToken.mintPrice(), 1 ether);
        assertEq(memeToken.owner(), address(creator));
    }

    // 测试铸币功能
    function testMintInscription() public {
        // 发行者部署 MemeToken
        vm.deal(address(creator), INITIAL_BALANCE);
        vm.prank(address(creator));
        address token = factory.deployInscription("TEST", 1000, 10, 1 ether);

        // 铸币者分配余额
        vm.deal(address(minter), INITIAL_BALANCE);
        uint256 minterInitialBalance = address(minter).balance;
        // 用铸币者身份铸币并支付 1 ether
        vm.prank(address(minter));
        factory.mintInscription{value: 1 ether}(token);
        MemeToken memeToken = MemeToken(token);
        // 校验铸币者获得了正确数量的 token，余额减少了 1 ether
        assertEq(memeToken.balanceOf(address(minter)), 10);
        assertEq(address(minter).balance, minterInitialBalance - 1 ether);
    }

    // 测试平台费和发行者费的分配
    function testFeeDistribution() public {
        // 发行者部署 MemeToken
        vm.deal(address(creator), INITIAL_BALANCE);
        vm.prank(address(creator));
        address token = factory.deployInscription("TEST", 1000, 10, 1 ether);

        // 铸币者分配余额
        vm.deal(address(minter), INITIAL_BALANCE);
        uint256 ownerBalanceBefore = address(factoryOwner).balance;
        uint256 creatorBalanceBefore = address(creator).balance;
        // 用铸币者身份铸币
        vm.prank(address(minter));
        factory.mintInscription{value: 1 ether}(token);
        // 校验平台方获得 0.01 ether，发行者获得 0.99 ether
        assertEq(address(factoryOwner).balance - ownerBalanceBefore, 0.01 ether);
        assertEq(address(creator).balance - creatorBalanceBefore, 0.99 ether);
    }

    // 测试不能超过总发行量
    function testMintExceedsTotalSupply() public {
        // 发行者部署 MemeToken
        vm.deal(address(creator), INITIAL_BALANCE);
        vm.prank(address(creator));
        address token = factory.deployInscription("TEST", 100, 10, 1 ether);
        vm.deal(address(minter), INITIAL_BALANCE);
        // 铸币 10 次，每次 10 个，正好到上限
        for(uint i = 0; i < 10; i++) {
            vm.prank(address(minter));
            factory.mintInscription{value: 1 ether}(token);
        }
        // 再铸币应 revert
        vm.prank(address(minter));
        vm.expectRevert("Exceeds total supply");
        factory.mintInscription{value: 1 ether}(token);
    }

    // 测试支付不足时应 revert
    function testInsufficientPayment() public {
        // 发行者部署 MemeToken
        vm.deal(address(creator), INITIAL_BALANCE);
        vm.prank(address(creator));
        address token = factory.deployInscription("TEST", 1000, 10, 1 ether);
        vm.deal(address(minter), INITIAL_BALANCE);
        // 用铸币者身份支付不足
        vm.prank(address(minter));
        vm.expectRevert("Insufficient payment");
        factory.mintInscription{value: 0.5 ether}(token);
    }

    // 允许测试合约接收 ETH
    receive() external payable {}
}

// Receiver 合约，专门用来接收 ETH，避免 EOA 地址收不到 ETH 导致测试失败
contract Receiver {
    receive() external payable {}
} 