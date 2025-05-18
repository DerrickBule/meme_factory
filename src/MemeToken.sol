// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 引入 OpenZeppelin 的 ERC20 和 Ownable 可升级合约
import "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

// MemeToken 合约，继承 ERC20 和 Ownable 可升级合约
contract MemeToken is ERC20Upgradeable, OwnableUpgradeable {
    // 总发行量上限
    uint256 public totalSupplyCap;
    // 每次铸币数量
    uint256 public perMint;
    // 每次铸币价格（wei）
    uint256 public mintPrice;
    // 工厂合约地址
    address public factory;
    // 是否已初始化
    bool private initialized;

    /**
     * @dev 初始化 MemeToken
     * @param symbol_ 代币符号
     * @param _totalSupply 总发行量上限
     * @param _perMint 每次铸币数量
     * @param _price 每次铸币价格
     */
    function initialize(
        string memory symbol_,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price
    ) external initializer {
        // 初始化 ERC20，设置名称和符号
        __ERC20_init("Meme Token", symbol_);
        // 初始化 Ownable，设置 owner 为调用者（工厂合约）
        __Ownable_init(msg.sender);
        // 设置其他参数
        totalSupplyCap = _totalSupply;
        perMint = _perMint;
        mintPrice = _price;
        factory = msg.sender;
        initialized = true;
    }

    /**
     * @dev 铸币函数，仅工厂合约可调用
     * @param to 接收者地址
     * @param amount 铸币数量
     */
    function mint(address to, uint256 amount) external {
        // 校验调用者是否为工厂合约
        require(msg.sender == factory, "Only factory can mint");
        // 校验是否已初始化
        require(initialized, "Not initialized");
        // 校验是否超过总发行量
        require(totalSupply() + amount <= totalSupplyCap, "Exceeds total supply");
        // 铸币
        _mint(to, amount);
    }

    /**
     * @dev 提取合约中的 ETH，仅 owner 可调用
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // 允许合约接收 ETH
    receive() external payable {}
} 