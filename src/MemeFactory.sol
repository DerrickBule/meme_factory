// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 引入 MemeToken 合约
import "./MemeToken.sol";

// Meme 工厂合约，负责部署和管理 MemeToken
contract MemeFactory {
    // MemeToken 实现合约地址（用于最小代理模式）
    address public immutable implementation;
    // 平台方地址（owner），收取 1% 平台费
    address public immutable owner;
    // 平台费比例（1%）
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 1; // 1%
    
    // 事件：新 MemeToken 部署
    event TokenDeployed(address indexed token, address indexed creator, string symbol);
    // 事件：MemeToken 被铸币
    event TokenMinted(address indexed token, address indexed minter, uint256 amount);
    
    // 构造函数，部署 MemeToken 实现合约，设置 owner
    constructor() {
        implementation = address(new MemeToken());
        owner = msg.sender;
    }
    
    /**
     * @dev 部署新的 MemeToken（最小代理模式）
     * @param symbol 代币符号
     * @param totalSupply 总发行量
     * @param perMint 每次铸币数量
     * @param price 每次铸币价格
     * @return 新部署的 MemeToken 地址
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        // 构造初始化数据
        bytes memory data = abi.encodeWithSelector(
            MemeToken.initialize.selector,
            symbol,
            totalSupply,
            perMint,
            price
        );
        // 部署最小代理合约
        address proxy = _deployProxy(data);
        // 转移 MemeToken 所有权给发行者
        MemeToken(proxy).transferOwnership(msg.sender);
        // 记录事件
        emit TokenDeployed(proxy, msg.sender, symbol);
        return proxy;
    }
    
    /**
     * @dev 铸造 MemeToken
     * @param tokenAddr MemeToken 地址
     */
    function mintInscription(address tokenAddr) external payable {
        MemeToken token = MemeToken(tokenAddr);
        // 校验 token 是否由本工厂部署
        require(token.factory() == address(this), "Invalid token");
        // 校验支付金额
        uint256 mintPrice = token.mintPrice();
        require(msg.value >= mintPrice, "Insufficient payment");
        // 计算平台费和发行者费
        uint256 platformFee = (mintPrice * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 creatorFee = mintPrice - platformFee;
        // 分发 ETH
        payable(owner).transfer(platformFee);
        payable(token.owner()).transfer(creatorFee);
        // 铸币
        uint256 perMint = token.perMint();
        token.mint(msg.sender, perMint);
        // 记录事件
        emit TokenMinted(tokenAddr, msg.sender, perMint);
    }
    
    /**
     * @dev 内部函数：部署最小代理合约
     * @param data 初始化 MemeToken 的 calldata
     * @return proxy 新部署的代理合约地址
     */
    function _deployProxy(bytes memory data) internal returns (address proxy) {
        bytes20 targetBytes = bytes20(implementation);
        assembly {
            let clone := mload(0x40)
            // EIP-1167 最小代理字节码
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            proxy := create(0, clone, 0x37)
        }
        require(proxy != address(0), "Proxy creation failed");
        // 初始化 MemeToken
        (bool success,) = proxy.call(data);
        require(success, "Initialization failed");
    }

    // 允许工厂合约接收 ETH
    receive() external payable {}
} 