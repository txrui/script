# 田小瑞一键脚本 v1.0.4

> 一个功能强大的 Linux 服务器管理脚本，提供系统优化、应用安装、网络诊断、安全配置等一站式服务。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

## ✨ 特性

- 🎨 **美观的交互界面** - 彩色输出，清晰的菜单结构
- 🔒 **安全可靠** - 输入验证、错误处理、安全下载
- 🚀 **功能丰富** - 涵盖系统管理、网络优化、应用安装等各个方面
- 📦 **一键安装** - 支持在线一键安装和本地运行
- 🛠️ **持续更新** - 定期更新，添加新功能和修复问题

## 📋 功能列表

### 系统优化
- ✅ 虚拟内存管理（添加/删除/自动挂载/Swappiness 设定）
- ✅ 镜像源管理（支持 Debian/Ubuntu/CentOS/Rocky/AlmaLinux）
- ✅ BBR 网络优化

### 应用安装
- ✅ 流媒体解锁测试
- ✅ 宝塔面板安装
- ✅ DPanel 面板安装
- ✅ CasaOS 面板安装
- ✅ qBittorrent 下载工具（系统版本/自定义版本）

### 系统维护
- ✅ 一键清理日志和缓存
- ✅ 防火墙管理（UFW/Firewalld）
- ✅ 系统时区修改
- ✅ 主机名修改
- ✅ Host 文件编辑
- ✅ 系统语言切换
- ✅ 服务器详细信息查看

### 系统工具
- ✅ SSH 密钥管理（生成/添加/删除/查看）
- ✅ 网络诊断工具（Ping/Traceroute/端口扫描/路由追踪）
- ✅ DNS 配置管理（查看/修改/测试）
- ✅ Docker 管理（安装/卸载/服务管理）
- ✅ 数据库管理（MySQL/MariaDB/PostgreSQL）
- ✅ Python 环境管理（安装/虚拟环境）

### 安全工具
- ✅ Fail2Ban 管理（安装/配置/服务管理）
- ✅ SSL 证书续签助手
- ✅ SSH 端口修改
- ✅ ICMP 响应控制

### 网络增强
- ✅ GitHub 加速配置
- ✅ NTP 时间同步
- ✅ 网络测试工具

### 快捷工具
- ✅ BBR 优化脚本（TCPX/BBR）
- ✅ 面板安装（哪吒/3x-ui/h-ui/s-ui/MCSManager）
- ✅ 网络测试（三网回程/测速/IP质量检测）
- ✅ 系统工具（Rclone/NFS客户端/端口转发/目录占用查看）
- ✅ 群辉工具（状态查看/硬盘温度/权限管理/密码修改）
- ✅ PVE 工具（源配置/磁盘管理）
- ✅ 系统重装（DD 重装）

## 🚀 快速开始

### 一键安装运行

```bash
curl -fsSL https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh | sudo bash
```

### 手动下载运行

```bash
# 下载脚本
wget -O txrui.sh https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh

# 添加执行权限
chmod +x txrui.sh

# 运行脚本（需要 root 权限）
sudo ./txrui.sh
```

## 📖 使用说明

### 系统要求

- **操作系统**: Debian/Ubuntu/CentOS/Rocky Linux/AlmaLinux
- **权限**: 需要 root 或 sudo 权限
- **网络**: 需要互联网连接（用于下载和安装）

### 主菜单说明

运行脚本后，会显示主菜单，包含以下分类：

1. **系统优化** - 虚拟内存、镜像源管理
2. **应用安装** - 流媒体测试、面板安装、服务器信息
3. **系统维护** - 清理、系统管理
4. **下载工具** - qBittorrent 安装
5. **系统工具** - SSH、网络、DNS、Docker、数据库、Python
6. **安全工具** - Fail2Ban、SSL 证书
7. **网络增强** - GitHub 加速、SSH 端口、ICMP、NTP
8. **面板工具** - CasaOS
9. **快捷工具** - BBR、面板、网络测试、群辉、PVE 等

### 常用功能示例

#### 添加虚拟内存

```
主菜单 → 1 (虚拟内存管理) → 选择大小 (2/3/4/5) → 确认
```

#### 更换镜像源

```
主菜单 → 2 (镜像源管理) → 选择系统类型 → 选择镜像源 → 确认
```

#### 安装 qBittorrent

```
主菜单 → 9 (安装系统默认版本QB) 或 10 (选择安装版本QB)
```

#### 网络诊断

```
主菜单 → 12 (网络诊断工具) → 选择诊断类型
```

## 🔧 功能详解

### 虚拟内存管理

支持快速添加 1G/2G/4G/8G 虚拟内存，或自定义大小。可设置开机自动挂载，支持 Swappiness 参数调整。

### 镜像源管理

支持以下系统的镜像源管理：
- Debian (11/12)
- Ubuntu (20.04/22.04/24.04)
- CentOS (7/8)
- Rocky Linux (8/9)
- AlmaLinux (8/9)

镜像源包括：阿里云、腾讯云、华为云、清华大学、中科大、网易等。

### qBittorrent 安装

- **系统版本**: 使用系统包管理器安装
- **自定义版本**: 从 GitHub 下载指定版本（支持最新版和指定版本号）

安装完成后会自动配置 systemd 服务，支持开机自启。

### Docker 管理

- 自动检测系统并安装 Docker
- 支持 Docker Compose 安装
- 服务管理（启动/停止/重启/状态查看）

### 数据库管理

支持 MySQL、MariaDB、PostgreSQL 的安装和管理。

### Python 环境管理

- 安装 Python 3.x
- 创建和管理虚拟环境
- pip 配置

## ⚠️ 注意事项

1. **权限要求**: 脚本需要 root 权限运行，请使用 `sudo` 执行
2. **备份重要数据**: 某些操作（如系统重装）会修改系统配置，请提前备份
3. **网络连接**: 需要稳定的互联网连接用于下载和安装
4. **系统兼容性**: 建议在干净的系统中使用，避免与现有配置冲突
5. **安全警告**: 某些操作会修改系统网络配置，请谨慎操作

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

- 提交 Bug: [Issues](https://github.com/txrui/script/issues)
- 功能建议: [Issues](https://github.com/txrui/script/issues)
- 代码贡献: [Pull Requests](https://github.com/txrui/script/pulls)

## 🐛 问题反馈

如果遇到问题或有功能建议，请通过以下方式反馈：

- **GitHub Issues**: [提交 Issue](https://github.com/txrui/script/issues)
- **脚本版本**: v1.0.4

## 📝 更新日志

### v1.0.4
- 修复各种Bug
  
### v1.0.3
- 新增虚拟内存 Swappiness 设定功能
- 优化虚拟内存管理菜单
- 改进用户体验和错误处理

### v1.0.2
- 更新版本号
- 优化界面显示
- 修复已知问题

### v1.0.1
- 初始版本发布
- 基础功能实现

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

感谢所有贡献者和使用者的支持！

---

**提示**: 使用前请仔细阅读说明，确保了解每个功能的作用和影响。

**⭐ 如果这个项目对你有帮助，请给个 Star 支持一下！**
