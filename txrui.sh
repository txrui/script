#!/bin/bash
#==============================================
# 田小瑞一键脚本 v1.0.3
#==============================================
#
# 一键运行命令:
# curl -fsSL https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh | sudo bash
#
# 或手动下载:
# wget -O txrui.sh https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh
# chmod +x txrui.sh && sudo ./txrui.sh

# 启用错误检查（在函数定义之前）
# 注意：交互式函数中可能需要使用 set +e 来允许错误继续执行
set -e

# ---------- 公共函数 ----------
ok()    { echo -e "${BOLD_GREEN}[✔]${NC} ${GREEN}$1${NC}"; }
warn()  { echo -e "${BOLD_YELLOW}[!]${NC} ${YELLOW}$1${NC}"; }
error() { echo -e "${BOLD_RED}[✘]${NC} ${RED}$1${NC}"; }
info()  { echo -e "${BOLD_CYAN}[ℹ]${NC} ${CYAN}$1${NC}"; }
success() { echo -e "${BOLD_GREEN}[✓]${NC} ${GREEN}$1${NC}"; }
question() { echo -e "${BOLD_MAGENTA}[?]${NC} ${MAGENTA}$1${NC}"; }

# 统一的等待用户输入函数
pause() {
    local message="${1:-按回车继续...}"
    echo -e "${DIM}$message${NC}"
    read -rp ""
}

# 安全的下载函数
safe_download() {
    local url="$1"
    local output="$2"
    local desc="${3:-文件}"

    info "正在下载 $desc..."
    if ! wget -q "$url" -O "$output" 2>/dev/null; then
        error "$desc 下载失败"
        return 1
    fi
    ok "$desc 下载成功"
    return 0
}

# 验证数字输入
validate_number() {
    local input="$1"
    local min="$2"
    local max="$3"

    [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge "$min" ] && [ "$input" -le "$max" ]
}

# 生成随机密码
generate_random_password() {
    local length="${1:-16}"
    # 使用 /dev/urandom 生成安全的随机密码
    if command -v openssl &> /dev/null; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    elif [ -c /dev/urandom ]; then
        tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
    else
        # 备用方法
        date +%s | sha256sum | base64 | head -c "$length"
    fi
}

# 清理输入中的危险字符
sanitize_input() {
    local input="$1"
    # 移除可能用于命令注入的字符
    echo "$input" | sed 's/[;&|`$(){}]//g' | sed "s/'//g" | sed 's/"//g'
}

# 验证IP地址格式
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # 检查每个八位字节是否在有效范围内
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ "$i" -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# 验证端口号
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    return 1
}

# ---------- 颜色变量 ----------
# 基础颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# 加粗颜色
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_MAGENTA='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'

# 背景颜色
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_CYAN='\033[46m'

# 特殊效果
NC='\033[0m' # No Color (重置)
DIM='\033[2m' # 暗淡
UNDERLINE='\033[4m' # 下划线
BLINK='\033[5m' # 闪烁

# 颜色美化函数
print_header() {
    local title="$1"
    echo -e "${BOLD_CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD_CYAN}║${NC} ${BOLD_WHITE}$title${NC} ${BOLD_CYAN}$(printf '%*s' $((60 - ${#title} - 2)) '')║${NC}"
    echo -e "${BOLD_CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_menu_header() {
    local title="$1"
    echo -e "${BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD_CYAN}  $title${NC}"
    echo -e "${BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_section() {
    local title="$1"
    echo -e "${BOLD_MAGENTA}【${title}】${NC}"
}

print_option() {
    local num="$1"
    local desc="$2"
    echo -e "  ${BOLD_GREEN}$num)${NC} ${CYAN}$desc${NC}"
}

print_option_pair() {
    local num1="$1"
    local desc1="$2"
    local num2="$3"
    local desc2="$4"
    printf "  ${BOLD_GREEN}%2s)${NC} ${CYAN}%-25s${NC} ${BOLD_GREEN}%2s)${NC} ${CYAN}%s${NC}\n" "$num1" "$desc1" "$num2" "$desc2"
}

print_separator() {
    echo -e "${BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_divider() {
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────────────${NC}"
}

# ---------- 常量定义 ----------
readonly SCRIPT_VERSION="v1.0.3"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com"
readonly QB_STATIC_REPO="userdocs/qbittorrent-nox-static"

# ---------- 虚拟内存管理 ----------
manage_swap_menu() {
  while true; do
    clear
    print_menu_header "虚拟内存管理"
    print_option "1" "查看当前虚拟内存"
    print_option "2" "添加 1G 虚拟内存"
    print_option "3" "添加 2G 虚拟内存"
    print_option "4" "添加 4G 虚拟内存"
    print_option "5" "添加 8G 虚拟内存"
    print_option "6" "删除虚拟内存"
    print_option "7" "开机自动挂载设置"
    print_option "8" "自定义添加虚拟内存"
    print_option "9" "Swappiness 设定"
    print_separator
    echo -e "  ${BOLD_RED}0)${NC} ${RED}返回主菜单${NC}"
    print_separator
    echo -ne "${BOLD_MAGENTA}请选择: ${NC}"
    read -r opt

    case "$opt" in
      1)
        echo ""
        swapon --show || echo "无激活的交换空间"
        echo ""
        pause ;;
      2) add_swap 1G ;;
      3) add_swap 2G ;;
      4) add_swap 4G ;;
      5) add_swap 8G ;;
      6)
    # 删除 /swapfile（用户自建 swap 文件）
    if [ -f /swapfile ]; then
        swapoff /swapfile 2>/dev/null
        rm -f /swapfile
        sed -i '/\/swapfile/d' /etc/fstab
        ok "已删除 /swapfile 虚拟内存"
    fi

    # 查找并处理系统默认 swap 分区或 swap 文件
    swapon --show=NAME --noheadings | while read -r swapdev; do
        swapoff "$swapdev" 2>/dev/null
        # 如果是文件，直接删除
        if [ -f "$swapdev" ]; then
            rm -f "$swapdev"
            ok "已删除 swap 文件: $swapdev"
        fi
        # 如果是分区，提示用户是否删除
        if [[ "$swapdev" =~ ^/dev/ ]]; then
            question "检测到 swap 分区 $swapdev。是否删除该分区? [y/N]: "
            read -r yn
            yn=${yn:-N}  # 默认不删除，防止误操作
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                # 删除分区（用 sfdisk 清空分区表）
                echo "正在删除分区 $swapdev ..."
                parted "$swapdev" rm 1 >/dev/null 2>&1
                ok "已删除 swap 分区 $swapdev"
            else
                ok "保留 swap 分区 $swapdev"
            fi
        fi
        # 清理 /etc/fstab 中对应 swap 行
        sed -i "\|$swapdev|d" /etc/fstab
    done

    pause
    ;;

      7)
        grep -q '/swapfile' /etc/fstab && ok "已设置自动挂载" || warn "未检测到自动挂载"
        pause ;;
      8)
        question "请输入虚拟内存大小（如 512M 或 3G）: "
        read -r custom_size
        if [[ ! $custom_size =~ ^[0-9]+[MmGg]$ ]]; then
          error "输入格式错误，请输入如 512M 或 2G"
          sleep 1
        else
          add_swap "$custom_size"
        fi ;;
      9) manage_swappiness ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

# ---------- 添加虚拟内存函数 ----------
add_swap() {
  size="$1"
  if [ -f /swapfile ]; then
    warn "检测到已有 swapfile，请先删除再添加"
    pause
    return
  fi

  echo "正在创建 ${size} 虚拟内存..."
  # 尝试用 fallocate，不支持则用 dd
if ! fallocate -l "$size" /swapfile 2>/dev/null; then
    unit="${size: -1}"
    num="${size%[GgMm]}"
    if [[ $unit == "G" || $unit == "g" ]]; then
        count=$((num*1024))
    else
        count=$num
    fi
    if ! dd if=/dev/zero of=/swapfile bs=1M count=$count status=progress; then
      error "创建 swap 文件失败"
      return 1
    fi
  fi

  if ! chmod 600 /swapfile; then
    error "设置 swap 文件权限失败"
    return 1
  fi
  
  if ! mkswap /swapfile >/dev/null 2>&1; then
    error "格式化 swap 文件失败"
    rm -f /swapfile
    return 1
  fi
  
  if ! swapon /swapfile; then
    error "启用 swap 失败"
    return 1
  fi
  
  if ! grep -q '/swapfile' /etc/fstab; then
    if ! echo '/swapfile none swap sw 0 0' >> /etc/fstab; then
      warn "无法写入 /etc/fstab，swap 可能不会在重启后自动启用"
    fi
  fi
  ok "已成功添加 ${size} 虚拟内存并启用"
  pause
}

# ---------- Swappiness 管理函数 ----------
manage_swappiness() {
  clear
  print_menu_header "Swappiness 设定"
  
  # 获取当前 swappiness 值
  local current_swappiness
  current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
  
  echo ""
  info "当前 Swappiness 值: ${BOLD_GREEN}${current_swappiness}${NC}"
  echo ""
  print_section "Swappiness 说明"
  echo -e "  ${CYAN}Swappiness${NC} 是 Linux 内核参数，控制系统使用 swap 空间的倾向性"
  echo -e "  ${CYAN}取值范围${NC}: 0-100"
  echo -e "  ${CYAN}0${NC}   - 尽可能不使用 swap（优先使用物理内存）"
  echo -e "  ${CYAN}1-10${NC} - 低优先级使用 swap（推荐用于服务器）"
  echo -e "  ${CYAN}60${NC}  - 默认值（平衡使用）"
  echo -e "  ${CYAN}100${NC} - 尽可能使用 swap（不推荐）"
  echo ""
  print_separator
  
  print_option "1" "查看当前 Swappiness 值"
  print_option "2" "修改 Swappiness 值"
  print_option "3" "设置为推荐值 (1 - 适合服务器)"
  print_option "4" "设置为默认值 (60)"
  print_option "5" "设置为最小值 (0 - 禁用 swap 优先)"
  print_separator
  echo -e "  ${BOLD_RED}0)${NC} ${RED}返回${NC}"
  print_separator
  echo -ne "${BOLD_MAGENTA}请选择: ${NC}"
  read -r opt
  
  case "$opt" in
    1)
      echo ""
      info "当前 Swappiness 值: ${BOLD_GREEN}${current_swappiness}${NC}"
      if [ -f /etc/sysctl.conf ]; then
        if grep -q "vm.swappiness" /etc/sysctl.conf; then
          echo ""
          info "配置文件中的设置:"
          grep "vm.swappiness" /etc/sysctl.conf
        else
          warn "未在 /etc/sysctl.conf 中找到永久配置"
        fi
      fi
      echo ""
      pause
      ;;
    2)
      echo ""
      question "请输入新的 Swappiness 值 (0-100): "
      read -r new_value
      
      if [[ "$new_value" =~ ^[0-9]+$ ]] && [ "$new_value" -ge 0 ] && [ "$new_value" -le 100 ]; then
        # 临时设置（立即生效）
        if sysctl -w vm.swappiness="$new_value" >/dev/null 2>&1; then
          ok "Swappiness 已临时设置为: ${new_value}"
          
          # 永久设置（写入配置文件）
          if [ -f /etc/sysctl.conf ]; then
            # 删除旧配置（如果存在）
            sed -i '/^vm\.swappiness=/d' /etc/sysctl.conf
            # 添加新配置
            echo "vm.swappiness=$new_value" >> /etc/sysctl.conf
            ok "已写入 /etc/sysctl.conf，重启后仍有效"
          else
            warn "无法写入 /etc/sysctl.conf"
          fi
          
          echo ""
          info "当前值: $(cat /proc/sys/vm/swappiness)"
        else
          error "设置失败，请检查权限"
        fi
      else
        error "无效输入，请输入 0-100 之间的数字"
      fi
      echo ""
      pause
      ;;
    3)
      echo ""
      info "正在设置为推荐值 1（适合服务器环境）..."
      if sysctl -w vm.swappiness=1 >/dev/null 2>&1; then
        if [ -f /etc/sysctl.conf ]; then
          sed -i '/^vm\.swappiness=/d' /etc/sysctl.conf
          echo "vm.swappiness=1" >> /etc/sysctl.conf
        fi
        ok "Swappiness 已设置为 1（推荐值）"
        info "当前值: $(cat /proc/sys/vm/swappiness)"
      else
        error "设置失败"
      fi
      echo ""
      pause
      ;;
    4)
      echo ""
      info "正在设置为默认值 60..."
      if sysctl -w vm.swappiness=60 >/dev/null 2>&1; then
        if [ -f /etc/sysctl.conf ]; then
          sed -i '/^vm\.swappiness=/d' /etc/sysctl.conf
          echo "vm.swappiness=60" >> /etc/sysctl.conf
        fi
        ok "Swappiness 已设置为 60（默认值）"
        info "当前值: $(cat /proc/sys/vm/swappiness)"
      else
        error "设置失败"
      fi
      echo ""
      pause
      ;;
    5)
      echo ""
      warn "设置为 0 将尽可能不使用 swap，可能导致内存不足时系统不稳定"
      question "确认设置为 0? [y/N]: "
      read -r confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if sysctl -w vm.swappiness=0 >/dev/null 2>&1; then
          if [ -f /etc/sysctl.conf ]; then
            sed -i '/^vm\.swappiness=/d' /etc/sysctl.conf
            echo "vm.swappiness=0" >> /etc/sysctl.conf
          fi
          ok "Swappiness 已设置为 0"
          info "当前值: $(cat /proc/sys/vm/swappiness)"
        else
          error "设置失败"
        fi
      else
        info "已取消"
      fi
      echo ""
      pause
      ;;
    0) return ;;
    *) warn "无效选项"; sleep 1 ;;
  esac
}

# ---------- 通用镜像源管理 ----------
BACKUP_DIR="/root"
DATE=$(date +%Y%m%d_%H%M%S)

# 检测系统类型和版本
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID:$VERSION_ID:$PRETTY_NAME"
    elif [ -f /etc/redhat-release ]; then
        # 兼容老版本 RHEL/CentOS
        if grep -q "CentOS" /etc/redhat-release; then
            version=$(grep -oP '\d+\.\d+' /etc/redhat-release | head -1)
            echo "centos:$version:CentOS $version"
        elif grep -q "Red Hat" /etc/redhat-release; then
            version=$(grep -oP '\d+\.\d+' /etc/redhat-release | head -1)
            echo "rhel:$version:Red Hat Enterprise Linux $version"
        else
            echo "unknown:unknown:Unknown RHEL-based system"
        fi
    else
        echo "unknown:unknown:Unknown system"
    fi
}

# 检查包管理器
get_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Debian/Ubuntu 官方源
debian_official_sources() {
    local distro=$1
    local ver=$2

    if [[ "$distro" == "debian" ]]; then
        if [[ "$ver" == "11" ]]; then
            cat <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free

deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free

deb http://security.debian.org/debian-security bullseye-security main contrib non-free
deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
        elif [[ "$ver" == "12" ]]; then
            cat <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free
deb-src http://deb.debian.org/debian bookworm main contrib non-free

deb http://deb.debian.org/debian bookworm-updates main contrib non-free
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free

deb http://security.debian.org/debian-security bookworm-security main contrib non-free
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free
EOF
        fi
    elif [[ "$distro" == "ubuntu" ]]; then
        # Ubuntu 版本映射
        local codename=""
        case $ver in
            "20.04") codename="focal" ;;
            "21.04") codename="hirsute" ;;
            "21.10") codename="impish" ;;
            "22.04") codename="jammy" ;;
            "22.10") codename="kinetic" ;;
            "23.04") codename="lunar" ;;
            "23.10") codename="mantic" ;;
            "24.04") codename="noble" ;;
        esac

        if [[ -n "$codename" ]]; then
            cat <<EOF
deb http://archive.ubuntu.com/ubuntu/ $codename main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $codename main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ $codename-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $codename-updates main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ $codename-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $codename-security main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ $codename-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
        fi
    fi
}

# CentOS/RHEL/AlmaLinux/Rocky Linux 官方源
rhel_official_sources() {
    local distro=$1
    local ver=$2

    # 获取主版本号
    local major_ver=$(echo $ver | cut -d'.' -f1)

    case $distro in
        "centos")
            cat <<EOF
[base]
name=CentOS-\$releasever - Base
baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever

[updates]
name=CentOS-\$releasever - Updates
baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever

[extras]
name=CentOS-\$releasever - Extras
baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever
EOF
            ;;
        "almalinux")
            cat <<EOF
[baseos]
name=AlmaLinux \$releasever - BaseOS
baseurl=https://repo.almalinux.org/almalinux/\$releasever/BaseOS/\$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-\$releasever

[appstream]
name=AlmaLinux \$releasever - AppStream
baseurl=https://repo.almalinux.org/almalinux/\$releasever/AppStream/\$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-\$releasever
EOF
            ;;
        "rocky")
            cat <<EOF
[baseos]
name=Rocky Linux \$releasever - BaseOS
baseurl=https://dl.rockylinux.org/pub/rocky/\$releasever/BaseOS/\$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-\$releasever

[appstream]
name=Rocky Linux \$releasever - AppStream
baseurl=https://dl.rockylinux.org/pub/rocky/\$releasever/AppStream/\$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-\$releasever
EOF
            ;;
        "rhel")
            # RHEL 需要订阅或其他配置，这里提供基本的配置
            cat <<EOF
# RHEL 官方源需要订阅，请先配置 subscription-manager
# 或者使用 CentOS 兼容源
EOF
            ;;
    esac
}

# Fedora 官方源
fedora_official_sources() {
    local ver=$1
    cat <<EOF
[fedora]
name=Fedora \$releasever - \$basearch
baseurl=http://download.fedoraproject.org/pub/fedora/linux/releases/\$releasever/Everything/\$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch

[fedora-updates]
name=Fedora \$releasever - \$basearch - Updates
baseurl=http://download.fedoraproject.org/pub/fedora/linux/updates/\$releasever/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
EOF
}

# openSUSE 官方源
opensuse_official_sources() {
    local ver=$1
    cat <<EOF
# openSUSE Leap $ver 官方源
URI: http://download.opensuse.org/distribution/leap/$ver/repo/oss/
URI: http://download.opensuse.org/update/leap/$ver/oss/

# 非OSS包
URI: http://download.opensuse.org/distribution/leap/$ver/repo/non-oss/
URI: http://download.opensuse.org/update/leap/$ver/non-oss/
EOF
}

# Arch Linux 官方源
arch_official_sources() {
    cat <<EOF
# Arch Linux 官方源
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirror.leaseweb.net/archlinux/\$repo/os/\$arch
EOF
}

# 阿里云镜像源
aliyun_sources() {
    local distro=$1
    local ver=$2

    if [[ "$distro" == "debian" ]]; then
        if [[ "$ver" == "11" ]]; then
            cat <<EOF
deb http://mirrors.aliyun.com/debian/ bullseye main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bullseye main contrib non-free

deb http://mirrors.aliyun.com/debian/ bullseye-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bullseye-updates main contrib non-free

deb http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free
deb-src http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free
EOF
        elif [[ "$ver" == "12" ]]; then
            cat <<EOF
deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bookworm main contrib non-free

deb http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free

deb http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
deb-src http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
EOF
        fi
    elif [[ "$distro" == "ubuntu" ]]; then
        # Ubuntu 版本映射到代号
        local codename=""
        case $ver in
            "20.04") codename="focal" ;;
            "21.04") codename="hirsute" ;;
            "21.10") codename="impish" ;;
            "22.04") codename="jammy" ;;
            "22.10") codename="kinetic" ;;
            "23.04") codename="lunar" ;;
            "23.10") codename="mantic" ;;
            "24.04") codename="noble" ;;
        esac

        if [[ -n "$codename" ]]; then
            cat <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
        fi
    elif [[ "$distro" =~ ^(centos|almalinux|rocky|rhel)$ ]]; then
        local major_ver=$(echo $ver | cut -d'.' -f1)
        cat <<EOF
[base]
name=Aliyun Base - $distro \$releasever
baseurl=https://mirrors.aliyun.com/$distro/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/$distro/RPM-GPG-KEY-$distro-\$releasever

[updates]
name=Aliyun Updates - $distro \$releasever
baseurl=https://mirrors.aliyun.com/$distro/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/$distro/RPM-GPG-KEY-$distro-\$releasever

[extras]
name=Aliyun Extras - $distro \$releasever
baseurl=https://mirrors.aliyun.com/$distro/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/$distro/RPM-GPG-KEY-$distro-\$releasever

[epel]
name=Aliyun EPEL
baseurl=https://mirrors.aliyun.com/epel/\$releasever/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-\$releasever
EOF
    elif [[ "$distro" == "fedora" ]]; then
        cat <<EOF
[fedora]
name=Aliyun Fedora \$releasever - \$basearch
baseurl=https://mirrors.aliyun.com/fedora/releases/\$releasever/Everything/\$basearch/os/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/fedora/RPM-GPG-KEY-fedora-\$releasever-\$basearch

[fedora-updates]
name=Aliyun Fedora \$releasever - \$basearch - Updates
baseurl=https://mirrors.aliyun.com/fedora/updates/\$releasever/\$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/fedora/RPM-GPG-KEY-fedora-\$releasever-\$basearch
EOF
    fi
}

# 腾讯云镜像源
tencent_sources() {
    local distro=$1
    local ver=$2

    if [[ "$distro" == "debian" || "$distro" == "ubuntu" ]]; then
        aliyun_sources "$distro" "$ver" | sed 's|mirrors.aliyun.com|mirrors.tencent.com|g'
    elif [[ "$distro" =~ ^(centos|almalinux|rocky|rhel)$ ]]; then
        aliyun_sources "$distro" "$ver" | sed 's|mirrors.aliyun.com|mirrors.tencent.com|g'
    elif [[ "$distro" == "fedora" ]]; then
        aliyun_sources "$distro" "$ver" | sed 's|mirrors.aliyun.com|mirrors.tencent.com|g'
    fi
}

# 华为云镜像源
huawei_sources() {
    local distro=$1
    local ver=$2

    if [[ "$distro" == "debian" || "$distro" == "ubuntu" ]]; then
        aliyun_sources "$distro" "$ver" | sed 's|mirrors.aliyun.com|repo.huaweicloud.com|g'
    elif [[ "$distro" =~ ^(centos|almalinux|rocky|rhel)$ ]]; then
        aliyun_sources "$distro" "$ver" | sed 's|mirrors.aliyun.com|repo.huaweicloud.com|g'
    elif [[ "$distro" == "fedora" ]]; then
        aliyun_sources "$distro" "$ver" | sed 's|mirrors.aliyun.com|repo.huaweicloud.com|g'
    fi
}

# 通用备份功能
backup_sources() {
    local system_info="$1"
    local pm=$(get_package_manager)

    case $pm in
        "apt")
            local config_dir="/etc/apt"
            local backup_name="apt"
            ;;
        "dnf"|"yum")
            local config_dir="/etc/yum.repos.d"
            local backup_name="yum"
            ;;
        "zypper")
            local config_dir="/etc/zypp/repos.d"
            local backup_name="zypper"
            ;;
        "pacman")
            local config_dir="/etc/pacman.d"
            local backup_name="pacman"
            ;;
        *)
            error "不支持的包管理器: $pm"
            return 1
            ;;
    esac

    success "开始备份 $config_dir 到 $BACKUP_DIR/${backup_name}_backup_$DATE.tar.gz"
    if [ -d "$config_dir" ]; then
        tar czf "$BACKUP_DIR/${backup_name}_backup_$DATE.tar.gz" "$config_dir"
        echo "🎉 备份完成：$BACKUP_DIR/${backup_name}_backup_$DATE.tar.gz"
    else
        error "配置目录不存在: $config_dir"
        return 1
    fi
}

list_backups(){
    echo "📦 可用备份列表："
    ls -1t $BACKUP_DIR/*_backup_*.tar.gz 2>/dev/null || echo "无备份文件"
}

restore_backup(){
    list_backups
    read -rp "请输入要恢复的备份文件全路径名（或输入 'cancel' 取消）: " backup_file
    if [[ "$backup_file" == "cancel" ]]; then
        echo "已取消恢复操作。"
        return 1
    fi
    if [[ ! -f "$backup_file" ]]; then
        error "备份文件不存在：$backup_file"
        return 1
    fi

    # 确定配置目录
    local pm=$(get_package_manager)
    case $pm in
        "apt")
            local config_dir="/etc/apt"
            ;;
        "dnf"|"yum")
            local config_dir="/etc/yum.repos.d"
            ;;
        "zypper")
            local config_dir="/etc/zypp/repos.d"
            ;;
        "pacman")
            local config_dir="/etc/pacman.d"
            ;;
        *)
            error "不支持的包管理器: $pm"
            return 1
            ;;
    esac

    # 验证备份文件存在且有效
    if [ ! -f "$backup_file" ]; then
        error "备份文件不存在: $backup_file"
        return 1
    fi
    
    # 验证备份文件是否为有效的tar.gz文件
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        error "备份文件无效或已损坏: $backup_file"
        return 1
    fi

    # 确认操作
    warn "⚠️  警告: 此操作将删除 $config_dir 目录并恢复备份"
    read -rp "确认继续? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "操作已取消"
        return 0
    fi

    echo "🔁 正在恢复备份..."
    # 创建临时备份以防恢复失败
    local temp_backup="/tmp/${config_dir##*/}.backup.$(date +%s)"
    if [ -d "$config_dir" ]; then
        sudo cp -r "$config_dir" "$temp_backup" 2>/dev/null || true
    fi
    
    if sudo rm -rf "$config_dir" && sudo mkdir -p "$config_dir" && sudo tar xzf "$backup_file" -C /; then
        success "恢复完成。"
        # 清理临时备份
        sudo rm -rf "$temp_backup" 2>/dev/null || true
    return 0
    else
        error "恢复失败！"
        # 尝试恢复临时备份
        if [ -d "$temp_backup" ]; then
            warn "尝试恢复原配置..."
            sudo rm -rf "$config_dir" 2>/dev/null || true
            sudo mv "$temp_backup" "$config_dir" 2>/dev/null || true
        fi
        return 1
    fi
}

# 导入 GPG 公钥
import_gpg_keys() {
    local distro=$1

    if [[ "$distro" == "debian" || "$distro" == "ubuntu" ]]; then
        sudo mkdir -p /etc/apt/trusted.gpg.d
        local keys=( 0E98404D386FA1D9 6ED0E7B82643E131 605C66F00D6C9793 54404762BBB6E853 BDE6D2B9216EC7A8 )
        for key in "${keys[@]}"; do
            echo "🔑 导入公钥: $key"
            tmpdir=$(mktemp -d)
            if gpg --no-default-keyring --keyring "$tmpdir/temp.gpg" --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" >/dev/null 2>&1; then
                sudo gpg --no-default-keyring --keyring "$tmpdir/temp.gpg" --export "$key" | sudo tee "/etc/apt/trusted.gpg.d/${key}.gpg" >/dev/null
                success "公钥 $key 导入成功"
            else
                error "公钥 $key 导入失败"
            fi
            rm -rf "$tmpdir"
        done
    elif [[ "$distro" =~ ^(centos|almalinux|rocky|rhel)$ ]]; then
        echo "🔑 RPM-based 系统通常已包含必要的 GPG 密钥"
    elif [[ "$distro" == "fedora" ]]; then
        echo "🔑 Fedora 系统通常已包含必要的 GPG 密钥"
    fi
}

# 写入源配置
write_sources() {
    local system_info="$1"
    local mirror_type="$2"

    # 解析系统信息
    local distro=$(echo $system_info | cut -d: -f1)
    local version=$(echo $system_info | cut -d: -f2)
    local pretty_name=$(echo $system_info | cut -d: -f3)

    local pm=$(get_package_manager)

    echo "🧹 清理旧配置..."

    case $pm in
        "apt")
            # Debian/Ubuntu
            # 危险操作：删除系统关键目录，需要严格验证和确认
            if [ ! -d "/etc/apt" ]; then
                warn "/etc/apt 目录不存在，跳过删除步骤"
            else
                warn "⚠️  警告: 即将删除系统关键目录 /etc/apt"
                warn "此操作将删除所有APT配置和源设置"
                read -rp "确认继续? [y/N]: " confirm_apt
                if [[ ! "$confirm_apt" =~ ^[Yy]$ ]]; then
                    error "操作已取消"
                    return 1
                fi
                
                # 创建备份
                local apt_backup="/tmp/etc-apt.backup.$(date +%Y%m%d_%H%M%S).tar.gz"
                echo "📦 正在创建备份: $apt_backup"
                if ! sudo tar -czf "$apt_backup" -C / etc/apt 2>/dev/null; then
                    error "备份失败，操作已取消"
                    return 1
                fi
                ok "备份已创建: $apt_backup"
                
            echo "🧹 删除旧的 /etc/apt 目录..."
                if ! sudo rm -rf /etc/apt; then
                    error "删除失败"
                    return 1
                fi
            fi
            echo "📂 创建必要目录..."
            sudo mkdir -p /etc/apt/apt.conf.d /etc/apt/preferences.d /etc/apt/trusted.gpg.d

            echo "📝 写入新的源配置..."
            case $mirror_type in
                "official")
                    debian_official_sources "$distro" "$version" | sudo tee /etc/apt/sources.list >/dev/null
                    ;;
                "aliyun")
                    aliyun_sources "$distro" "$version" | sudo tee /etc/apt/sources.list >/dev/null
                    ;;
                "tencent")
                    tencent_sources "$distro" "$version" | sudo tee /etc/apt/sources.list >/dev/null
                    ;;
                "huawei")
                    huawei_sources "$distro" "$version" | sudo tee /etc/apt/sources.list >/dev/null
                    ;;
                *)
                    error "未知镜像类型: $mirror_type"
                    return 1
                    ;;
            esac

            echo '# 默认apt配置' | sudo tee /etc/apt/apt.conf.d/99custom >/dev/null
            echo 'Acquire::Retries "3";' | sudo tee -a /etc/apt/apt.conf.d/99custom >/dev/null

            echo "🔧 导入常用 GPG 公钥..."
            import_gpg_keys "$distro"

            echo "🔄 更新软件包列表..."
            sudo apt-get update && sudo apt update
            ;;

        "dnf"|"yum")
            # RHEL/CentOS/Fedora/AlmaLinux/Rocky Linux
            local repo_dir="/etc/yum.repos.d"
            echo "🧹 备份并清理旧的 repo 文件..."
            sudo mkdir -p /etc/yum.repos.d.backup 2>/dev/null
            sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d.backup/ 2>/dev/null || true

            echo "📝 写入新的源配置..."
            case $mirror_type in
                "official")
                    if [[ "$distro" == "fedora" ]]; then
                        fedora_official_sources "$version" | sudo tee /etc/yum.repos.d/fedora-official.repo >/dev/null
                    else
                        rhel_official_sources "$distro" "$version" | sudo tee /etc/yum.repos.d/$distro-official.repo >/dev/null
                    fi
                    ;;
                "aliyun")
                    aliyun_sources "$distro" "$version" | sudo tee /etc/yum.repos.d/aliyun.repo >/dev/null
                    ;;
                "tencent")
                    tencent_sources "$distro" "$version" | sudo tee /etc/yum.repos.d/tencent.repo >/dev/null
                    ;;
                "huawei")
                    huawei_sources "$distro" "$version" | sudo tee /etc/yum.repos.d/huawei.repo >/dev/null
                    ;;
                *)
                    error "未知镜像类型: $mirror_type"
                    return 1
                    ;;
            esac

            echo "🔄 清理并更新软件包缓存..."
            sudo $pm clean all
            sudo $pm makecache
            ;;

        "zypper")
            # openSUSE
            echo "🧹 清理旧的仓库配置..."
            sudo zypper repos --export-backup /root/zypper-backup_$DATE.repo

            echo "📝 写入新的源配置..."
            case $mirror_type in
                "official")
                    opensuse_official_sources "$version" | sudo tee /etc/zypp/repos.d/opensuse-official.repo >/dev/null
                    ;;
                "aliyun")
                    aliyun_sources "$distro" "$version" | sudo tee /etc/zypp/repos.d/aliyun.repo >/dev/null
                    ;;
                *)
                    error "openSUSE 目前仅支持官方源和阿里云源"
                    return 1
                    ;;
            esac

            echo "🔄 刷新仓库..."
            sudo zypper refresh
            ;;

        "pacman")
            # Arch Linux
            echo "🧹 备份当前配置..."
            sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup.$DATE

            echo "📝 写入新的源配置..."
            case $mirror_type in
                "official")
                    arch_official_sources | sudo tee /etc/pacman.d/mirrorlist >/dev/null
                    ;;
                *)
                    error "Arch Linux 目前仅支持官方源"
                    return 1
                    ;;
            esac

            echo "🔄 更新包数据库..."
            sudo pacman -Syu --noconfirm
            ;;

        *)
            error "不支持的包管理器: $pm"
            return 1
            ;;
    esac

    echo "🎉 源配置更新成功！"
}
# ------------ 通用镜像源管理菜单 -----------------
manage_sources_menu() {
  while true; do
    clear
    print_menu_header "通用镜像源管理工具"

    # 检测系统信息
    local system_info=$(detect_system)
    local distro=$(echo $system_info | cut -d: -f1)
    local version=$(echo $system_info | cut -d: -f2)
    local pretty_name=$(echo $system_info | cut -d: -f3)
    local pm=$(get_package_manager)

    echo -e "${BOLD_CYAN}📦 当前系统：${BOLD_WHITE}$pretty_name${NC}"
    echo -e "${BOLD_CYAN}🔧 包管理器：${BOLD_GREEN}$pm${NC}"
    echo ""

    # 显示支持的镜像源选项（根据系统类型）
    echo -e "${BOLD_YELLOW}请选择操作：${NC}"
    print_option_pair "1" "备份当前配置" "2" "恢复配置备份"

    case $pm in
        "apt")
            print_option_pair "3" "使用 官方源" "4" "使用 阿里云源"
            print_option_pair "5" "使用 腾讯云源" "6" "使用 华为云源"
            ;;
        "dnf"|"yum")
            print_option_pair "3" "使用 官方源" "4" "使用 阿里云源"
            print_option_pair "5" "使用 腾讯云源" "6" "使用 华为云源"
            ;;
        "zypper")
            print_option_pair "3" "使用 官方源" "4" "使用 阿里云源"
            ;;
        "pacman")
            print_option "3" "使用 官方源"
            ;;
        *)
            error "不支持的包管理器: $pm"
            pause
            break
            ;;
    esac

    echo ""
    print_option_pair "7" "更新软件包列表" "0" "返回主菜单"
    print_separator
    echo -ne "${BOLD_MAGENTA}请输入选项: ${NC}"
    read -r choice

    case $choice in
      1) backup_sources "$system_info"; pause ;;
      2) restore_backup && pause ;;
      3) write_sources "$system_info" "official"; pause ;;
      4)
        if [[ "$pm" == "apt" || "$pm" == "dnf" || "$pm" == "yum" ]]; then
          write_sources "$system_info" "aliyun"; pause
        else
          error "此镜像源不适用于当前系统"; pause
        fi
        ;;
      5)
        if [[ "$pm" == "apt" || "$pm" == "dnf" || "$pm" == "yum" ]]; then
          write_sources "$system_info" "tencent"; pause
        else
          error "此镜像源不适用于当前系统"; pause
        fi
        ;;
      6)
        if [[ "$pm" == "apt" || "$pm" == "dnf" || "$pm" == "yum" ]]; then
          write_sources "$system_info" "huawei"; pause
        else
          error "此镜像源不适用于当前系统"; pause
        fi
        ;;
      7)
        case $pm in
          "apt") info "正在更新 apt 源..."; sudo apt-get update && sudo apt update ;;
          "dnf") info "正在更新 dnf 缓存..."; sudo dnf makecache ;;
          "yum") info "正在更新 yum 缓存..."; sudo yum makecache ;;
          "zypper") info "正在刷新 zypper 仓库..."; sudo zypper refresh ;;
          "pacman") info "正在更新 pacman 数据库..."; sudo pacman -Sy ;;
        esac
        success "更新完成"
        pause
        ;;
      0) break ;;
      *) warn "无效选项，请重新输入"; pause ;;
    esac
  done
}

# ---------- BBR 管理 ----------
manage_bbr() {
  clear
  print_menu_header "BBR 管理"
  print_option "1" "启用 BBR"
  print_option "2" "查看 BBR 状态"
  print_separator
  echo -e "  ${BOLD_RED}0)${NC} ${RED}返回主菜单${NC}"
  print_separator
  echo -ne "${BOLD_MAGENTA}请选择: ${NC}"
  read -r opt
  case "$opt" in
    1)
      echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
      echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
      sysctl -p
      ok "BBR 已启用"
      pause ;;
    2)
      sysctl net.ipv4.tcp_congestion_control
      pause ;;
    0) return ;;
  esac
}

# ---------- BBR 优化 ----------
optimize_bbr() {
  clear
  print_menu_header "BBR 优化"
  info "正在优化 TCP 参数..."
  cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_rmem='4096 87380 67108864'
net.ipv4.tcp_wmem='4096 65536 67108864'
EOF
  sysctl -p
  ok "优化完成"
  pause
}

# ---------- 流媒体测试 ----------
streaming_test() {
  clear
  print_menu_header "流媒体测试"
  warn "安全警告: 即将执行远程脚本"
  echo "脚本来源: https://github.com/lmc999/RegionRestrictionCheck/raw/main/check.sh"
  echo "此操作将从互联网下载并执行脚本，请确保您信任该来源。"
  read -rp "确认继续? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  bash <(curl -sSL https://github.com/lmc999/RegionRestrictionCheck/raw/main/check.sh)
  pause
}

# ---------- 安装宝塔 ----------
install_bt_panel() {
  clear
  print_menu_header "安装宝塔面板"
  info "正在下载安装脚本..."
  wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh
  info "正在执行安装..."
  bash install.sh
  pause
}

# ---------- 安装 DPanel ----------
install_dpanel() {
  clear
  print_menu_header "安装 DPanel 面板"
  warn "安全警告: 即将执行远程安装脚本"
  echo -e "${CYAN}脚本来源: ${BOLD_WHITE}https://raw.githubusercontent.com/Dpanel-Server/DPanel/master/install.sh${NC}"
  echo -e "${YELLOW}此操作将从互联网下载并执行脚本，可能会修改系统配置。${NC}"
  echo -e "${YELLOW}请确保您信任该来源并已备份重要数据。${NC}"
  echo ""
  question "确认继续安装? [y/N]: "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "安装已取消"
    pause
    return
  fi
  bash <(curl -sSL https://raw.githubusercontent.com/Dpanel-Server/DPanel/master/install.sh)
  pause
}

# ---------- 系统信息 ----------
system_info() {
  clear
  print_menu_header "系统详细信息"

  # 基本信息
  echo -e "${BOLD_CYAN}📋 基本信息${NC}"
  print_divider
  echo -e "${CYAN}主机名:${NC} ${BOLD_WHITE}$(hostname)${NC}"
  echo -e "${CYAN}系统版本:${NC} ${BOLD_WHITE}$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')${NC}"
  echo -e "${CYAN}内核版本:${NC} ${BOLD_WHITE}$(uname -r)${NC}"
  echo -e "${CYAN}CPU 架构:${NC} ${BOLD_WHITE}$(uname -m)${NC}"
  echo -e "${CYAN}CPU 信息:${NC} ${BOLD_WHITE}$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')${NC}"
  echo -e "${CYAN}CPU 核心:${NC} ${BOLD_GREEN}$(nproc)${NC}"
  echo ""

  # 内存信息（用 MB/GB 显示）
  echo -e "${BOLD_CYAN}💾 内存信息${NC}"
  print_divider
  mem_used=$(free -m | awk '/Mem:/ {printf "%.1f", $3/1024}')
  mem_total=$(free -m | awk '/Mem:/ {printf "%.1f", $2/1024}')
  echo -e "${CYAN}内存使用:${NC} ${BOLD_YELLOW}${mem_used}GB${NC} / ${BOLD_GREEN}${mem_total}GB${NC}"
  echo ""

  # 磁盘使用
  echo -e "${BOLD_CYAN}💿 磁盘信息${NC}"
  print_divider
  disk_used=$(df -h / | awk 'NR==2 {print $3}')
  disk_total=$(df -h / | awk 'NR==2 {print $2}')
  disk_percent=$(df -h / | awk 'NR==2 {print $5}')
  echo -e "${CYAN}磁盘使用:${NC} ${BOLD_YELLOW}${disk_used}${NC} / ${BOLD_GREEN}${disk_total}${NC} (${BOLD_RED}${disk_percent}${NC})"
  echo ""

  # ---------------- 交换空间 ----------------
  echo -e "${BOLD_CYAN}🔄 交换空间${NC}"
  print_divider
	swap_used_mb=$(free -m | awk '/^Swap:/{print $3}')
	swap_total_mb=$(free -m | awk '/^Swap:/{print $2}')

	if [[ $swap_total_mb -eq 0 ]]; then
    echo -e "${CYAN}交换空间:${NC} ${RED}未启用${NC}"
	else
    if [[ $swap_total_mb -ge 1024 ]]; then
        swap_used=$(awk "BEGIN {printf \"%.1fG\", $swap_used_mb/1024}")
        swap_total=$(awk "BEGIN {printf \"%.1fG\", $swap_total_mb/1024}")
    else
        swap_used="${swap_used_mb}M"
        swap_total="${swap_total_mb}M"
    fi
    echo -e "${CYAN}交换空间:${NC} ${BOLD_YELLOW}${swap_used}${NC} / ${BOLD_GREEN}${swap_total}${NC}"
	fi
  echo ""

  # 系统运行时间（中文显示）
  echo -e "${BOLD_CYAN}⏱️  系统运行时间${NC}"
  print_divider
  uptime_sec=$(awk '{print int($1)}' /proc/uptime)
  days=$((uptime_sec / 86400))
  hours=$(( (uptime_sec % 86400) / 3600 ))
  mins=$(( (uptime_sec % 3600) / 60 ))

  uptime_str="已运行 "
  ((days > 0)) && uptime_str+="${days}天 "
  ((hours > 0)) && uptime_str+="${hours}小时 "
  ((mins > 0)) && uptime_str+="${mins}分钟"
  echo -e "${CYAN}系统运行时间:${NC} ${BOLD_GREEN}${uptime_str}${NC}"
  echo ""

  # 系统负载
  echo -e "${BOLD_CYAN}📊 系统负载${NC}"
  print_divider
  echo -e "${CYAN}系统负载:${NC} ${BOLD_WHITE}$(uptime | awk -F'load average:' '{print $2}')${NC}"
  echo ""

  # 网络信息
  get_network_info

  print_separator
  pause
}
# 获取网络接口信息和公网IP
get_network_info() {
  echo -e "${BOLD_CYAN}🌐 网络接口信息${NC}"
  print_separator

  # 获取所有网络接口信息
  local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

  for iface in $interfaces; do
    # 获取该接口的所有IPv4地址
    local ipv4_addrs=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}(?=/\d+)')
    # 获取该接口的所有IPv6地址（排除本地链路地址）
    local ipv6_addrs=$(ip -6 addr show $iface 2>/dev/null | grep -oP '(?<=inet6\s)[0-9a-f:]+(?=/\d+)' | grep -v '^fe80:' | grep -v '^::1')

    # 只显示有IP地址的接口
    if [ -n "$ipv4_addrs" ] || [ -n "$ipv6_addrs" ]; then
      echo "📡 接口: $iface"

      # 显示所有内网IPv4地址
      if [ -n "$ipv4_addrs" ]; then
        local count=0
        for ipv4 in $ipv4_addrs; do
          # 判断是否为公网IP（简单的检查）
          if [[ $ipv4 =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|127\.|0\.) ]]; then
            echo "   └─ 🏠 内网IPv4: $ipv4"
          else
            echo "   └─ 🌍 公网IPv4: $ipv4"
          fi
          ((count++))
        done
      fi

      # 显示所有内网IPv6地址
      if [ -n "$ipv6_addrs" ]; then
        local count=0
        for ipv6 in $ipv6_addrs; do
          # IPv6地址类型判断（简化版）
          if [[ $ipv6 =~ ^(fc00:|fd00:|fe80:|::1) ]]; then
            echo "   └─ 🏠 内网IPv6: $ipv6"
          else
            echo "   └─ 🌍 公网IPv6: $ipv6"
          fi
          ((count++))
        done
      fi

      # 检查是否为默认网关接口
      if ip route show default 2>/dev/null | grep -q "$iface"; then
        echo "   └─ 🚪 默认网关接口"
      fi
      echo ""
    fi
  done

  # 如果没有找到任何有IP的接口，显示提示
  local has_ip_interfaces=false
  for iface in $interfaces; do
    local ipv4_check=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    local ipv6_check=$(ip -6 addr show $iface 2>/dev/null | grep -oP '(?<=inet6\s)[0-9a-f:]+' | grep -v '^fe80:' | grep -v '^::1')
    if [ -n "$ipv4_check" ] || [ -n "$ipv6_check" ]; then
      has_ip_interfaces=true
      break
    fi
  done

  if [ "$has_ip_interfaces" = false ]; then
    error "未检测到任何配置了IP地址的网络接口"
    echo ""
  fi

  # 外网IP检测（通过公网API）
  echo ""
  echo "🌐 外网IP检测:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📡 通过互联网API检测实际公网IP..."

  # 快速获取公网IPv4（使用最快的API）
  local public_ipv4=""
  local fastest_ipv4_url=""

  local ipv4_apis=(
    "https://api.ipify.org"
    "https://ipv4.ip.sb/ip"
    "https://ifconfig.me/ip"
    "https://ipinfo.io/ip"
  )

  for url in "${ipv4_apis[@]}"; do
    local ip=$(timeout 2 curl -4 -s --max-time 1 "$url" 2>/dev/null || echo "")
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      public_ipv4="$ip"
      fastest_ipv4_url="$url"
      break
    fi
  done

  # 快速获取公网IPv6
  local public_ipv6=""
  local fastest_ipv6_url=""

  local ipv6_apis=(
    "https://api64.ipify.org"
    "https://ipv6.ip.sb/ip"
    "https://ifconfig.co/ip"
  )

  for url in "${ipv6_apis[@]}"; do
    local ip=$(timeout 2 curl -6 -s --max-time 1 "$url" 2>/dev/null || echo "")
    if [[ $ip =~ ^[0-9a-fA-F:]+$ ]] && [[ ${#ip} -ge 7 ]]; then
      public_ipv6="$ip"
      fastest_ipv6_url="$url"
      break
    fi
  done

  # 显示外网IP结果
  if [ -n "$public_ipv4" ]; then
    success "🌍 外网IPv4: $public_ipv4"
    echo "   └─ 数据源: ${fastest_ipv4_url#https://}"
  else
    error "🌍 无法获取外网IPv4地址 (可能无IPv4公网连接)"
  fi

  if [ -n "$public_ipv6" ]; then
    success "🌍 外网IPv6: $public_ipv6"
    echo "   └─ 数据源: ${fastest_ipv6_url#https://}"
  else
    error "🌍 无法获取外网IPv6地址 (可能无IPv6公网连接)"
  fi

  # 显示DNS信息
  echo ""
  echo "🔍 DNS服务器:"
  local dns_servers=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
  if [ -n "$dns_servers" ]; then
    echo "   └─ $dns_servers"
  else
    echo "   └─ 未配置或无法读取"
  fi
}

# ---------- 一键清理系统 ----------
clean_system() {
  clear
  print_menu_header "一键清理系统缓存和垃圾文件"

  local total_cleaned=0

  echo "🧹 开始执行系统清理..."
  echo ""

  # 1. APT 包管理器清理
  if command -v apt &> /dev/null; then
    echo "📦 清理 APT 缓存..."
    apt autoremove -y 2>/dev/null && success "已移除孤立包"
    apt autoclean -y 2>/dev/null && success "已清理下载缓存"
    apt clean -y 2>/dev/null && success "已清理包缓存"
  fi

  # 2. 系统日志清理
  echo ""
  echo "📝 清理系统日志..."
  if command -v journalctl &> /dev/null; then
    journalctl --vacuum-time=7d 2>/dev/null && success "已清理7天前的系统日志"
  fi

  # 3. 临时文件清理
  echo ""
  echo "🗂️  清理临时文件..."
  # 清理 /tmp 目录（排除当前会话）
  find /tmp -type f -atime +7 -delete 2>/dev/null && success "已清理7天前的临时文件"

  # 清理 /var/tmp
  find /var/tmp -type f -atime +30 -delete 2>/dev/null && success "已清理30天前的系统临时文件"

  # 4. 缩略图缓存清理
  echo ""
  echo "🖼️  清理用户缓存..."
  if [ -d /home ]; then
    for user_home in /home/*; do
      if [ -d "$user_home" ]; then
        # 清理缩略图缓存
        if [ -d "$user_home/.cache/thumbnails" ]; then
          rm -rf "$user_home/.cache/thumbnails"/* 2>/dev/null && success "已清理用户 $(basename $user_home) 的缩略图缓存"
        fi
        # 清理 Firefox 缓存（如果存在）
        if [ -d "$user_home/.cache/mozilla" ]; then
          find "$user_home/.cache/mozilla" -type f -name "*.cache" -mtime +30 -delete 2>/dev/null
          success "已清理用户 $(basename $user_home) 的 Firefox 缓存"
        fi
      fi
    done
  fi

  # 清理 root 用户缓存
  if [ -d /root/.cache/thumbnails ]; then
    rm -rf /root/.cache/thumbnails/* 2>/dev/null && success "已清理 root 用户缩略图缓存"
  fi

  # 5. Docker 清理（如果安装了 Docker）
  echo ""
  echo "🐳 检查 Docker 清理..."
  if command -v docker &> /dev/null; then
    echo "🧹 清理 Docker 系统..."
    docker system prune -f 2>/dev/null && success "已清理 Docker 未使用的镜像和容器"
    docker volume prune -f 2>/dev/null && success "已清理 Docker 未使用的卷"
  fi

  # 6. 媒体服务器缓存清理
  echo ""
  echo "🎬 检查媒体服务器缓存..."
  # Emby 全面清理
  if [ -d "/opt/emby" ]; then
    echo "🎥 清理 Emby 服务器缓存和文件..."

    # 1. 转码临时文件清理
    if [ -d "/opt/emby/transcoding-temp" ]; then
      find "/opt/emby/transcoding-temp" -type f -mmin +60 -delete 2>/dev/null && echo "✅ 已清理1小时前的 Emby 转码临时文件"
      find "/opt/emby/transcoding-temp" -type d -empty -delete 2>/dev/null || true
    fi

    # 2. 图片缓存清理
    if [ -d "/opt/emby/cache/images" ]; then
      find "/opt/emby/cache/images" -type f -mtime +30 -delete 2>/dev/null && echo "✅ 已清理30天前的 Emby 图片缓存"
    fi

    # 3. 元数据缓存清理
    if [ -d "/opt/emby/metadata" ]; then
      # 清理旧的元数据缓存（保留最近90天）
      find "/opt/emby/metadata" -type f -mtime +90 -delete 2>/dev/null && echo "✅ 已清理90天前的 Emby 元数据缓存"
    fi

    # 4. 字幕缓存清理
    if [ -d "/opt/emby/data/subtitles" ]; then
      find "/opt/emby/data/subtitles" -type f -mtime +30 -delete 2>/dev/null && echo "✅ 已清理30天前的 Emby 字幕缓存"
    fi

    # 5. 日志文件清理
    if [ -d "/opt/emby/logs" ]; then
      # 压缩7天前的日志
      find "/opt/emby/logs" -type f -name "*.log" -mtime +7 -exec gzip {} \; 2>/dev/null && echo "✅ 已压缩7天前的 Emby 日志文件"
      # 删除30天前的压缩日志
      find "/opt/emby/logs" -type f -name "*.gz" -mtime +30 -delete 2>/dev/null && echo "✅ 已清理30天前的 Emby 压缩日志"
    fi

    # 6. 数据库临时文件清理
    if [ -f "/opt/emby/data/library.db" ]; then
      # SQLite WAL 和 SHM 文件
      rm -f "/opt/emby/data/library.db-wal" 2>/dev/null && echo "✅ 已清理 Emby 数据库 WAL 文件"
      rm -f "/opt/emby/data/library.db-shm" 2>/dev/null && echo "✅ 已清理 Emby 数据库 SHM 文件"
    fi

    # 7. 插件缓存清理
    if [ -d "/opt/emby/plugins" ]; then
      find "/opt/emby/plugins" -type f -name "*.cache" -mtime +7 -delete 2>/dev/null && success "已清理7天前的 Emby 插件缓存"
    fi

    # 8. 临时文件清理
    find "/tmp" -type f -name "emby_*" -mmin +60 -delete 2>/dev/null && success "已清理1小时前的 Emby 临时文件"

    # 9. 重启 Emby 服务以清理内存
    if command -v systemctl &> /dev/null && systemctl is-active --quiet emby-server 2>/dev/null; then
      echo "🔄 重启 Emby 服务以清理内存..."
      systemctl restart emby-server 2>/dev/null && success "已重启 Emby 服务，内存已清理"
    fi

    echo "🎉 Emby 清理完成！"
  fi

  # Jellyfin 缓存清理（如果存在）
  if [ -d "/var/lib/jellyfin" ]; then
    echo "🎞️ 清理 Jellyfin 缓存..."
    # 清理转码缓存
    if [ -d "/var/lib/jellyfin/transcodes" ]; then
      find "/var/lib/jellyfin/transcodes" -type f -mmin +60 -delete 2>/dev/null && echo "✅ 已清理1小时前的 Jellyfin 转码缓存"
    fi
    # 清理元数据缓存（保留最近30天）
    if [ -d "/var/lib/jellyfin/metadata" ]; then
      find "/var/lib/jellyfin/metadata" -type f -mtime +30 -delete 2>/dev/null && echo "✅ 已清理30天前的 Jellyfin 元数据缓存"
    fi
  fi

  # Plex 缓存清理（如果存在）
  if [ -d "/var/lib/plexmediaserver" ]; then
    echo "📺 清理 Plex 缓存..."
    # 清理转码缓存
    if [ -d "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Cache/Transcode" ]; then
      find "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Cache/Transcode" -type f -mmin +60 -delete 2>/dev/null && success "已清理1小时前的 Plex 转码缓存"
    fi
  fi

  # 7. 系统缓存清理
  echo ""
  echo "💾 清理系统缓存..."
  # 清理 pagecache、dentries 和 inodes
  sync
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && success "已清理系统页面缓存"

  # 7. 软件包缓存清理（针对不同发行版）
  echo ""
  echo "🔧 检查其他包管理器缓存..."

  # DNF/YUM 缓存清理
  if command -v dnf &> /dev/null; then
    dnf clean all 2>/dev/null && success "已清理 DNF 缓存"
  elif command -v yum &> /dev/null; then
    yum clean all 2>/dev/null && success "已清理 YUM 缓存"
  fi

  # Pacman 缓存清理
  if command -v paccache &> /dev/null; then
    paccache -rk2 2>/dev/null && success "已清理 Pacman 缓存（保留2个版本）"
  elif command -v pacman &> /dev/null; then
    pacman -Sc --noconfirm 2>/dev/null && success "已清理 Pacman 缓存"
  fi

  # Zypper 缓存清理
  if command -v zypper &> /dev/null; then
    zypper clean -a 2>/dev/null && success "已清理 Zypper 缓存"
  fi

  # 8. 崩溃报告清理
  echo ""
  echo "📋 清理崩溃报告..."
  if [ -d /var/crash ]; then
    find /var/crash -type f -mtime +30 -delete 2>/dev/null && success "已清理30天前的崩溃报告"
  fi

  # 9. 磁盘空间统计
  echo ""
  echo "📊 清理完成！磁盘使用情况："
  df -h / | tail -1

  echo ""
  ok "🎉 系统清理完成！建议重启系统以获得最佳效果。"
  pause
}

# 一键开启/关闭服务器防火墙
manage_firewall() {
  while true; do
    clear
    print_menu_header "防火墙管理"

    # 检测可用防火墙
    if command -v ufw >/dev/null 2>&1; then
      fw_type="ufw"
      fw_name="UFW"
      fw_status=$(sudo ufw status | grep -i "Status" | awk '{print $2}')
      case "$fw_status" in
        inactive) status_text="未开启" ;;
        active) status_text="已开启" ;;
        *) status_text="未知状态" ;;
      esac
    elif command -v firewall-cmd >/dev/null 2>&1; then
      fw_type="firewalld"
      fw_name="Firewalld"
      if systemctl is-active --quiet firewalld; then
        status_text="已开启"
      else
        status_text="未开启"
      fi
    elif command -v iptables >/dev/null 2>&1; then
      fw_type="iptables"
      fw_name="iptables"
      status_text="请手动管理规则"
    else
      fw_type="none"
      fw_name="未安装防火墙"
      status_text="未安装"
    fi

    # 显示防火墙状态
    echo -e "${CYAN}防火墙类型:${NC} ${BOLD_WHITE}$fw_name${NC}  ${CYAN}状态:${NC} ${BOLD_GREEN}$status_text${NC}"
    print_separator

    echo "1) 开启防火墙 (永久生效)"
    echo "2) 关闭防火墙 (永久生效)"
    echo "3) 临时关闭防火墙 (不改变开机自启)"
    echo "4) 重启防火墙"
    echo "0) 返回上级菜单"
    read -rp "请输入选项: " choice

    case $choice in
      1)
        case $fw_type in
          ufw)
            sudo ufw enable
            sudo systemctl enable ufw
            ;;
          firewalld)
            sudo systemctl start firewalld
            sudo systemctl enable firewalld
            ;;
          iptables)
            echo "⚠ iptables 需自行添加规则并保存"
            ;;
          *)
            error "未安装防火墙"
            ;;
        esac
        success "防火墙已开启（永久）"
        read -p "按回车继续..."
        ;;
      2)
        case $fw_type in
          ufw)
            sudo ufw disable
            sudo systemctl disable ufw
            ;;
          firewalld)
            sudo systemctl stop firewalld
            sudo systemctl disable firewalld
            ;;
          iptables)
            echo "⚠ iptables 需自行清空规则并禁用自启"
            ;;
          *)
            error "未安装防火墙"
            ;;
        esac
        success "防火墙已关闭（永久）"
        read -p "按回车继续..."
        ;;
      3)
        case $fw_type in
          ufw)
            sudo ufw disable
            echo "⚠ 防火墙已临时关闭 (开机仍可能启动)"
            ;;
          firewalld)
            sudo systemctl stop firewalld
            echo "⚠ 防火墙已临时关闭 (开机仍可能启动)"
            ;;
          iptables)
            echo "⚠ iptables 需手动清空规则"
            ;;
          *)
            error "未安装防火墙"
            ;;
        esac
        read -p "按回车继续..."
        ;;
      4)
        case $fw_type in
          ufw)
            sudo ufw disable
            sudo ufw enable
            ;;
          firewalld)
            sudo systemctl restart firewalld
            ;;
          iptables)
            echo "⚠ iptables 需手动重启规则"
            ;;
          *)
            error "未安装防火墙"
            ;;
        esac
        echo "🔄 防火墙已重启"
        read -p "按回车继续..."
        ;;
      0)
        break
        ;;
      *)
        echo "❗ 无效选项"
        read -p "按回车继续..."
        ;;
    esac
  done
}

#修改系统时区
change_timezone() {
  while true; do
    clear
    current_tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
    print_menu_header "系统时区管理"
    echo -e "${CYAN}当前时区:${NC} ${BOLD_GREEN}$current_tz${NC}"
    print_separator
    echo "1) 中国 (Asia/Shanghai)"
    echo "2) 日本 (Asia/Tokyo)"
    echo "3) 俄罗斯 (Europe/Moscow)"
    echo "4) 美国 (America/New_York)"
    echo "5) 香港 (Asia/Hong_Kong)"
    echo "6) 自定义时区"
    echo "0) 返回上级菜单"
    read -rp "请选择时区: " choice

    case $choice in
      1) tz="Asia/Shanghai" ;;
      2) tz="Asia/Tokyo" ;;
      3) tz="Europe/Moscow" ;;
      4) tz="America/New_York" ;;
      5) tz="Asia/Hong_Kong" ;;
      6)
        read -rp "请输入自定义时区 (如 Europe/London): " tz
        if ! timedatectl list-timezones | grep -q "^$tz$"; then
          error "时区无效"
          read -p "按回车继续..."
          continue
        fi
        ;;
      0) return ;;
      *) error "无效选项"; pause ; continue ;;
    esac

    sudo timedatectl set-timezone "$tz"
    success "时区已修改为 $tz"
    read -p "按回车继续..."
    break
  done
}

#修改主机名
change_hostname() {
  current_hostname=$(hostname)
  echo "当前主机名: $current_hostname"
  read -rp "请输入新的主机名: " new_hostname
  if [ -n "$new_hostname" ]; then
    sudo hostnamectl set-hostname "$new_hostname"
    success "主机名已修改为 $new_hostname"
    echo "请重启或重新登录以使更改生效"
  else
    error "主机名不能为空"
  fi
  read -p "按回车继续..."
}
#修改 /etc/hosts
edit_hosts() {
  echo "⚠️ 正在编辑 /etc/hosts 文件，请确保格式正确"
  sudo nano /etc/hosts
}
#切换系统语言
change_language() {
  while true; do
    clear
    current_lang=$(locale | grep LANG= | cut -d= -f2)
    echo "=================================="
    echo "        系统语言管理"
    echo "        当前语言: $current_lang"
    echo "=================================="
    echo "【中文系列】"
    echo "1) 简体中文 (zh_CN.UTF-8)"
    echo "2) 繁体中文-台湾 (zh_TW.UTF-8)"
    echo "3) 繁体中文-香港 (zh_HK.UTF-8)"
    echo ""
    echo "【亚洲语言】"
    echo "4) 日语 (ja_JP.UTF-8)"
    echo "5) 韩语 (ko_KR.UTF-8)"
    echo ""
    echo "【欧美语言】"
    echo "6) 英文-美国 (en_US.UTF-8)"
    echo "7) 英文-英国 (en_GB.UTF-8)"
    echo "8) 德语 (de_DE.UTF-8)"
    echo "9) 法语 (fr_FR.UTF-8)"
    echo "10) 西班牙语 (es_ES.UTF-8)"
    echo ""
    echo "【其他选项】"
    echo "11) 自定义语言"
    echo "0) 返回上级菜单"
    echo "----------------------------------"
    read -rp "请选择语言: " choice

    case $choice in
      1) lang="zh_CN.UTF-8" ; lang_desc="简体中文" ;;
      2) lang="zh_TW.UTF-8" ; lang_desc="繁体中文-台湾" ;;
      3) lang="zh_HK.UTF-8" ; lang_desc="繁体中文-香港" ;;
      4) lang="ja_JP.UTF-8" ; lang_desc="日语" ;;
      5) lang="ko_KR.UTF-8" ; lang_desc="韩语" ;;
      6) lang="en_US.UTF-8" ; lang_desc="英文-美国" ;;
      7) lang="en_GB.UTF-8" ; lang_desc="英文-英国" ;;
      8) lang="de_DE.UTF-8" ; lang_desc="德语" ;;
      9) lang="fr_FR.UTF-8" ; lang_desc="法语" ;;
      10) lang="es_ES.UTF-8" ; lang_desc="西班牙语" ;;
      11)
        read -rp "请输入自定义语言 (如 pt_BR.UTF-8): " lang
        if ! locale -a 2>/dev/null | grep -q "^${lang}$"; then
          error "语言无效或未安装，请先安装相应的语言包"
          echo "💡 提示: 可以使用 'sudo apt install language-pack-${lang%%_*}' 安装"
          pause
          continue
        fi
        lang_desc="自定义语言 ($lang)"
        ;;
      0) return ;;
      *) error "无效选项"; pause ; continue ;;
    esac

    # 检查并安装语言包（如果需要）
    check_and_install_locale "$lang"

    # 设置系统语言
    if sudo update-locale LANG="$lang" 2>/dev/null; then
      success "系统语言已修改为 $lang_desc ($lang)"
      echo "请重启或重新登录以使更改生效"
      echo ""
      echo "💡 重启命令: sudo reboot"
      echo "💡 或重新登录当前用户"
    else
      error "语言设置失败，请检查系统日志"
    fi

    pause
    break
  done
}

# 检查并安装语言包
check_and_install_locale() {
  local target_lang="$1"

  # 检查语言是否已安装
  if locale -a 2>/dev/null | grep -q "^${target_lang}$"; then
    success "语言包已安装"
    return 0
  fi

  echo "🔄 检测到语言包未安装，正在尝试自动安装..."

  # 根据包管理器安装语言包
  if command -v apt &> /dev/null; then
    # Debian/Ubuntu
    local lang_code="${target_lang%%_*}"
    local install_cmd=""

    local packages=""
    case $lang_code in
      zh) packages="language-pack-zh-hans language-pack-zh-hant" ;;
      ja) packages="language-pack-ja" ;;
      ko) packages="language-pack-ko" ;;
      de) packages="language-pack-de" ;;
      fr) packages="language-pack-fr" ;;
      es) packages="language-pack-es" ;;
      en) packages="language-pack-en" ;;
      *) packages="locales-all" ;;
    esac

    if [ -n "$packages" ]; then
      echo "正在更新软件包列表并安装语言包: $packages"
      # 安全执行命令：先更新，再安装，不使用eval
      if sudo apt update && sudo apt install -y $packages; then
        success "语言包安装成功"
        # 重新生成locale
        sudo locale-gen "$target_lang" 2>/dev/null || true
        return 0
      else
        error "语言包安装失败"
        return 1
      fi
    fi

  elif command -v dnf &> /dev/null; then
    # RHEL/CentOS/AlmaLinux
    local lang_packages=""
    case "${target_lang%%_*}" in
      zh) lang_packages="glibc-langpack-zh" ;;
      ja) lang_packages="glibc-langpack-ja" ;;
      ko) lang_packages="glibc-langpack-ko" ;;
      de) lang_packages="glibc-langpack-de" ;;
      fr) lang_packages="glibc-langpack-fr" ;;
      es) lang_packages="glibc-langpack-es" ;;
      en) lang_packages="glibc-langpack-en" ;;
    esac

    if [ -n "$lang_packages" ]; then
      echo "执行: sudo dnf install -y $lang_packages"
      if sudo dnf install -y $lang_packages; then
        success "语言包安装成功"
        return 0
      fi
    fi

  elif command -v pacman &> /dev/null; then
    # Arch Linux
    echo "执行: sudo pacman -S --noconfirm glibc"
    if sudo pacman -S --noconfirm glibc; then
      echo "✅ 语言包安装成功"
      return 0
    fi
  fi

  echo "⚠️ 自动安装失败，请手动安装语言包"
  return 1
}

# ---------- 自定义安装 qBittorrent ----------
install_qbittorrent_custom() {
    # 检查必要的工具
    for cmd in wget chmod mv systemctl; do
        if ! command -v "$cmd" &> /dev/null; then
            error "缺少必要的工具: $cmd"
            return 1
        fi
    done

    # --- 配置参数 ---
    APP_NAME="qbittorrent-nox"
    INSTALL_PATH="/usr/local/bin/$APP_NAME"
    TARGET_USER="root"

    echo "-------------------------------------------------------"
    echo "      qBittorrent 版本选择安装工具"
    echo "-------------------------------------------------------"
    echo "请选择要安装的 qBittorrent 版本："
    echo ""
    echo "=== v5.1.x 系列 (最新稳定版) ==="
    echo "1) v5.1.4 (最新推荐)"
    echo "2) v5.1.3"
    echo "3) v5.1.2"
    echo "4) v5.1.1"
    echo "5) v5.1.0"
    echo ""
    echo -e "${BOLD_CYAN}=== v5.0.x 系列 ===${NC}"
    echo "6) v5.0.4"
    echo "7) v5.0.3"
    echo "8) v5.0.2"
    echo "9) v5.0.1"
    echo "10) v5.0.0"
    echo ""
    echo -e "${BOLD_CYAN}=== v4.6.x 系列 (兼容版) ===${NC}"
    echo "11) v4.6.7"
    echo "12) v4.6.6"
    echo "13) v4.6.5"
    echo "14) v4.6.4"
    echo "15) v4.6.3"
    echo ""
    echo "0) 返回主菜单"
    echo "-------------------------------------------------------"
    read -p "请选择版本 [1-15, 0=返回]: " version_choice

    # 验证输入
    if ! validate_number "$version_choice" 0 15; then
        error "无效输入，请输入 0-15 之间的数字"
        return 1
    fi

    case $version_choice in
        # v5.1.x 系列
        1)
            VERSION="5.1.4"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.1.4_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        2)
            VERSION="5.1.3"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.1.3_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        3)
            VERSION="5.1.2"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.1.2_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        4)
            VERSION="5.1.1"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.1.1_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        5)
            VERSION="5.1.0"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.1.0_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        # v5.0.x 系列
        6)
            VERSION="5.0.4"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.0.4_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        7)
            VERSION="5.0.3"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.0.3_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        8)
            VERSION="5.0.2"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.0.2_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        9)
            VERSION="5.0.1"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.0.1_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        10)
            VERSION="5.0.0"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-5.0.0_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        # v4.6.x 系列
        11)
            VERSION="4.6.7"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.7_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        12)
            VERSION="4.6.6"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.6_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        13)
            VERSION="4.6.5"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.5_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        14)
            VERSION="4.6.4"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.4_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        15)
            VERSION="4.6.3"
            DOWNLOAD_URL="https://github.com/userdocs/qbittorrent-nox-static/releases/download/release-4.6.3_v2.0.10/x86_64-qbittorrent-nox"
            ;;
        0)
            return 0
            ;;
        *)
            error "无效选择，返回主菜单"
            return 1
            ;;
    esac

    echo "-------------------------------------------------------"
    echo "开始安装 qBittorrent $VERSION 静态版..."

    # 1. 自动检测本地是否存在二进制文件
    if [ -f "./$APP_NAME" ]; then
        echo "[检测] 发现当前目录已存在 $APP_NAME，跳过下载步骤。"
    else
        if ! safe_download "$DOWNLOAD_URL" "$APP_NAME" "qBittorrent $VERSION"; then
            error "请检查网络连接或手动上传二进制文件到当前目录"
            return 1
        fi
    fi

    # 2. 赋予执行权限并移动
    if ! chmod +x $APP_NAME; then
        error "设置执行权限失败"
        return 1
    fi
    
    if ! sudo mv $APP_NAME $INSTALL_PATH; then
        error "移动文件到 $INSTALL_PATH 失败"
        return 1
    fi
    echo "[成功] 二进制文件已部署到 $INSTALL_PATH"

    # 3. 预创建配置目录
    CONF_DIR="/$TARGET_USER/.config/qBittorrent"
    if ! mkdir -p $CONF_DIR; then
        error "创建配置目录失败: $CONF_DIR"
        return 1
    fi

    # 写入基础配置（接受协议并设置端口）
    if [ ! -f "$CONF_DIR/qBittorrent.conf" ]; then
        cat <<EOF > $CONF_DIR/qBittorrent.conf
[LegalNotice]
Accepted=true

[Preferences]
WebUI\Address=*
WebUI\Port=8080
WebUI\Username=admin
EOF
        echo "[配置] 已初始化基础配置文件。"
    fi

    # 4. 创建 Systemd 服务
    cat <<EOF | sudo tee /etc/systemd/system/$APP_NAME.service
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=simple
User=$TARGET_USER
ExecStart=$INSTALL_PATH
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 5. 启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable $APP_NAME
    sudo systemctl start $APP_NAME

    echo "-------------------------------------------------------"
    echo "安装完成！"
    echo "WebUI 地址: http://您的服务器IP:8080"
    echo "默认用户名: admin"
    echo ""
    echo "👉 请运行以下命令查看您的【随机初始密码】："
    echo "   journalctl -u $APP_NAME | grep password"
    echo "-------------------------------------------------------"
    echo "⚠️  安全提示: 登录后请务必在 WebUI 设置中将密码修改为强密码！"
}

# ---------- 安装 qBittorrent ----------
install_qbittorrent() {
    CONFIG_DIR="/root/.config/qBittorrent"
    CONF_FILE="$CONFIG_DIR/qBittorrent.conf"

    # 检测系统默认安装的 qBittorrent 版本
    info "检测 qBittorrent 版本..."
    if command -v apt &> /dev/null; then
        info "正在查询系统仓库中的 qBittorrent 版本..."
        QB_INFO=$(apt show qbittorrent-nox 2>/dev/null | grep -E "Version|Description" | head -2)
        if [ $? -eq 0 ] && [ -n "$QB_INFO" ]; then
            echo "系统默认安装版本信息："
            echo "$QB_INFO"
            echo ""
        else
            echo "无法获取版本信息，将尝试从 PPA 安装最新稳定版"
            echo ""
        fi
    else
        echo "未检测到 apt 包管理器"
        echo ""
    fi
    info "更新系统..."
    apt update && apt upgrade -y
    apt install -y software-properties-common wget nano curl gnupg lsb-release

    info "安装 qBittorrent-nox..."
    if [ -f /etc/lsb-release ]; then
        add-apt-repository ppa:qbittorrent-team/qbittorrent-stable -y
        apt update
    fi
    apt install -y qbittorrent-nox

    info "生成或修改配置文件..."
    mkdir -p $CONFIG_DIR

    # 判断是否已有配置文件
    if [ -f "$CONF_FILE" ]; then
        info "已有配置文件，更新为完整自定义配置..."
    else
        info "首次启动，生成配置文件..."
        qbittorrent-nox &
        sleep 5
        kill $!
    fi


    info "创建 systemd 服务..."
    SERVICE_FILE="/etc/systemd/system/qbittorrent.service"
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=qBittorrent-nox service
After=network.target

[Service]
User=root
ExecStart=/usr/bin/qbittorrent-nox
Restart=on-failure
LimitNOFILE=10240

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now qbittorrent

    success "安装/更新完成"
    echo -e "${BOLD_CYAN}WebUI 地址：${NC}${BOLD_GREEN}http://$(curl -s ifconfig.me):8080${NC}"
    echo -e "${CYAN}用户名：${NC}${BOLD_WHITE}admin${NC}"
    warn "密码：请查看配置文件 $CONF_FILE 或首次登录后修改密码"
    echo "WebUI 已设置为中文，服务已配置开机自启。"
}

# ---------- 系统环境检查 ----------
check_system() {
    # 检查是否为 root 用户
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 用户运行此脚本"
        exit 1
    fi

    # 检查必要的工具
    local required_tools=("curl" "wget" "awk" "sed")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "缺少必要的工具: ${missing_tools[*]}"
        info "正在尝试自动安装..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y "${missing_tools[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y "${missing_tools[@]}"
        else
            error "无法自动安装缺少的工具，请手动安装: ${missing_tools[*]}"
            exit 1
        fi
    fi
}

# ---------- 主菜单 ----------
main_menu() {
while true; do
    clear
    # 获取系统版本信息，只显示类似 "Ubuntu 22.04.5 LTS"
    if [[ -f /etc/os-release ]]; then
      OS_VERSION=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    else
      OS_VERSION="未知系统"
    fi

    # CPU核心数
    if command -v lscpu >/dev/null 2>&1; then
      CPU_CORES=$(lscpu | awk -F: '/^CPU\(s\)/{print $2}' | xargs)
    else
      CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
    fi

    MEM_TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')
	if [[ $MEM_TOTAL_MB -ge 1024 ]]; then
    MEM_TOTAL=$(awk "BEGIN {printf \"%.1fG\", $MEM_TOTAL_MB/1024}")
	else
    MEM_TOTAL="${MEM_TOTAL_MB}M"
	fi

	# 获取虚拟内存总量
	SWAP_TOTAL_MB=$(free -m | awk '/^Swap:/{print $2}')
	if [[ $SWAP_TOTAL_MB -ge 1024 ]]; then
    SWAP_TOTAL=$(awk "BEGIN {printf \"%.1fG\", $SWAP_TOTAL_MB/1024}")
	else
    SWAP_TOTAL="${SWAP_TOTAL_MB}M"
	fi

    # 根分区存储
    if command -v df >/dev/null 2>&1; then
      DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
    else
      DISK_TOTAL="未知"
    fi

    echo -e "${BOLD_CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD_CYAN}║${NC} ${BOLD_WHITE}                   田小瑞一键脚本 ${BOLD_GREEN}$SCRIPT_VERSION${NC} ${BOLD_WHITE}                      ${BOLD_CYAN}║${NC}"
    echo -e "${BOLD_CYAN}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD_CYAN}║${NC} ${CYAN}操作系统：${BOLD_WHITE}$OS_VERSION${NC} ${BOLD_CYAN}$(printf '%*s' $((67 - ${#OS_VERSION} - 5)) '')║${NC}"
    echo -e "${BOLD_CYAN}║${NC} ${CYAN}系统配置：${BOLD_GREEN}$CPU_CORES核${NC}  ${BOLD_BLUE}$MEM_TOTAL内存${NC}  ${BOLD_MAGENTA}$DISK_TOTAL存储${NC}  ${BOLD_YELLOW}$SWAP_TOTAL虚拟内存${NC} ${BOLD_CYAN}║${NC}"
    echo -e "${BOLD_CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_section "系统优化"
    print_option_pair "1" "虚拟内存管理" "2" "镜像源管理"
    echo ""
    print_section "应用安装"
    print_option_pair "3" "流媒体测试" "4" "安装宝塔面板"
    print_option_pair "5" "安装 DPanel 面板" "6" "服务器详细信息"
    echo ""
    print_section "系统维护"
    print_option_pair "7" "一键清理日志和缓存" "8" "系统管理"
    echo ""
    print_section "下载工具"
    print_option_pair "9" "安装系统默认版本QB" "10" "选择安装版本QB"
    echo ""
    print_section "系统工具"
    print_option_pair "11" "SSH密钥管理" "12" "网络诊断工具"
    print_option_pair "13" "DNS配置管理" "14" "Docker管理"
    print_option_pair "15" "数据库管理" "16" "Python环境管理"
    echo ""
    print_section "安全工具"
    print_option_pair "17" "Fail2Ban管理" "18" "SSL证书助手"
    echo ""
    print_section "网络增强"
    print_option_pair "19" "GitHub加速" "20" "SSH端口修改"
    print_option_pair "21" "ICMP响应控制" "22" "NTP时间同步"
    echo ""
    print_section "面板工具"
    print_option "23" "CasaOS面板"
    echo ""
    print_section "快捷工具"
    print_option "24" "快捷工具菜单（BBR/面板/网络测试/群辉/PVE等）"
    echo ""
    print_separator
    echo -e "  ${BOLD_RED}0)${NC} ${RED}退出${NC}"
    print_separator
    echo -ne "${BOLD_MAGENTA}请选择: ${NC}"
    read -r choice
    case "$choice" in
      1) manage_swap_menu ;;
      2) manage_sources_menu ;;
      3) streaming_test ;;
      4) install_bt_panel ;;
      5) install_dpanel ;;
      6) system_info ;;
      7) clean_system ;;
      8)
  while true; do
    clear
    print_menu_header "系统管理"
    print_option "1" "防火墙管理"
    print_option "2" "修改系统时区"
    print_option "3" "修改主机名"
    print_option "4" "修改 Host"
    print_option "5" "切换系统语言"
    print_separator
    echo -e "  ${BOLD_RED}0)${NC} ${RED}返回主菜单${NC}"
    print_separator
    echo -ne "${BOLD_MAGENTA}请输入选项: ${NC}"
    read -r sys_choice
    case $sys_choice in
      1) manage_firewall ;;
      2) change_timezone ;;
      3) change_hostname ;;
      4) edit_hosts ;;
      5) change_language ;;
      0) break ;;
      *) echo "❗ 无效选项"; read -p "按回车继续..." ;;
    esac
  done
  ;;
      9)
        info "开始安装 qBittorrent-nox..."
        # 调用函数或直接插入完整脚本
        install_qbittorrent
  ;;
      10)
        info "开始自定义安装 qBittorrent..."
        install_qbittorrent_custom
        ;;
      11) ssh_key_management ;;
      12) network_diagnostics ;;
      13) dns_management ;;
      14) docker_management ;;
      15) database_management ;;
      16) python_management ;;
      17) fail2ban_management ;;
      18) ssl_certificate_helper ;;
      19) github_acceleration ;;
      20) ssh_port_modification ;;
      21) icmp_control ;;
      22) ntp_sync ;;
      23) casaos_panel ;;
      24) quick_tools_menu ;;
      0) ok "退出脚本"; exit 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

# ---------- SSH密钥管理 ----------
ssh_key_management() {
  while true; do
    clear
    echo "=========================================="
    echo "         SSH 密钥管理"
    echo "=========================================="
    echo "1) 生成新的 SSH 密钥对"
    echo "2) 查看现有的 SSH 密钥"
    echo "3) 导入 SSH 公钥到 authorized_keys"
    echo "4) 导出 SSH 公钥"
    echo "5) 删除 SSH 密钥"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "生成新的 SSH 密钥对..."
        read -rp "请输入密钥文件名 (默认: id_rsa): " key_name
        key_name=${key_name:-id_rsa}
        key_path="$HOME/.ssh/$key_name"

        if [ -f "$key_path" ]; then
          read -rp "密钥已存在，是否覆盖? (y/N): " overwrite
          [[ $overwrite =~ ^[Yy]$ ]] || continue
        fi

        ssh-keygen -t rsa -b 4096 -f "$key_path" -N ""
        success "SSH 密钥对已生成:"
        echo "私钥: $key_path"
        echo "公钥: ${key_path}.pub"
        pause
        ;;
      2)
        echo "现有的 SSH 密钥:"
        if [ -d "$HOME/.ssh" ]; then
          ls -la "$HOME/.ssh"/id_* 2>/dev/null || echo "未找到 SSH 密钥文件"
        else
          echo "SSH 目录不存在"
        fi
        pause
        ;;
      3)
        echo "导入 SSH 公钥到 authorized_keys..."
        read -rp "请输入公钥文件路径或内容: " pubkey_input

        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"

        if [ -f "$pubkey_input" ]; then
          cat "$pubkey_input" >> "$HOME/.ssh/authorized_keys"
        else
          echo "$pubkey_input" >> "$HOME/.ssh/authorized_keys"
        fi

        chmod 600 "$HOME/.ssh/authorized_keys"
        success "公钥已导入到 authorized_keys"
        pause
        ;;
      4)
        echo "导出 SSH 公钥..."
        if [ -d "$HOME/.ssh" ]; then
          pubkeys=$(ls "$HOME/.ssh"/id_*.pub 2>/dev/null)
          if [ -n "$pubkeys" ]; then
            echo "找到的公钥文件:"
            echo "$pubkeys"
            echo ""
            echo "公钥内容:"
            for pubkey in $pubkeys; do
              echo "=== $pubkey ==="
              cat "$pubkey"
              echo ""
            done
          else
            echo "未找到公钥文件"
          fi
        else
          echo "SSH 目录不存在"
        fi
        pause
        ;;
      5)
        echo "删除 SSH 密钥..."
        if [ -d "$HOME/.ssh" ]; then
          echo "现有的密钥文件:"
          ls -la "$HOME/.ssh"/id_* 2>/dev/null || echo "未找到密钥文件"
          echo ""
          read -rp "请输入要删除的密钥文件名 (如 id_rsa): " key_to_delete
          if [ -n "$key_to_delete" ] && [ -f "$HOME/.ssh/$key_to_delete" ]; then
            rm -f "$HOME/.ssh/$key_to_delete" "$HOME/.ssh/${key_to_delete}.pub"
            success "已删除密钥: $key_to_delete"
          else
            error "密钥文件不存在"
          fi
        else
          echo "SSH 目录不存在"
        fi
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- 网络诊断工具 ----------
network_diagnostics() {
  while true; do
    clear
    print_menu_header "网络诊断工具"
    print_option "1" "Ping 测试"
    print_option "2" "Traceroute 路由跟踪"
    print_option "3" "DNS 查询"
    print_option "4" "端口连接测试"
    print_option "5" "网络速度测试"
    print_option "6" "查看网络连接"
    print_separator
    echo -e "  ${BOLD_RED}0)${NC} ${RED}返回主菜单${NC}"
    print_separator
    echo -ne "${BOLD_MAGENTA}请选择: ${NC}"
    read -r choice

    case $choice in
      1)
        question "请输入要 ping 的主机 (默认: 8.8.8.8): "
        read -r target
        target=${target:-8.8.8.8}
        info "正在 ping $target..."
        ping -c 4 "$target"
        pause
        ;;
      2)
        question "请输入要跟踪的路由主机 (默认: google.com): "
        read -r target
        target=${target:-google.com}
        info "正在跟踪到 $target 的路由..."
        if command -v traceroute &> /dev/null; then
          traceroute "$target"
        elif command -v tracepath &> /dev/null; then
          tracepath "$target"
        else
          error "未找到 traceroute 或 tracepath 命令"
        fi
        pause
        ;;
      3)
        question "请输入要查询的域名 (默认: google.com): "
        read -r domain
        domain=${domain:-google.com}
        info "正在查询 $domain 的 DNS 记录..."
        if command -v nslookup &> /dev/null; then
          nslookup "$domain"
        elif command -v dig &> /dev/null; then
          dig "$domain"
        else
          error "未找到 nslookup 或 dig 命令"
        fi
        pause
        ;;
      4)
        question "请输入主机: "
        read -r host
        question "请输入端口 (默认: 80): "
        read -r port
        port=${port:-80}
        info "正在测试 $host:$port 的连接..."
        if command -v nc &> /dev/null; then
          nc -zv "$host" "$port"
        elif command -v telnet &> /dev/null; then
          timeout 5 telnet "$host" "$port"
        else
          error "未找到 nc 或 telnet 命令"
        fi
        pause
        ;;
      5)
        info "网络速度测试..."
        if command -v curl &> /dev/null; then
          echo -e "${CYAN}下载速度测试 (从 cachefly):${NC}"
          curl -s -w "${GREEN}下载速度: %{speed_download} bytes/sec\n总时间: %{time_total}s${NC}\n" -o /dev/null http://cachefly.cachefly.net/100mb.test
        else
          error "需要 curl 命令来进行速度测试"
        fi
        pause
        ;;
      6)
        echo -e "${BOLD_CYAN}当前网络连接:${NC}"
        print_separator
        echo -e "${BOLD_CYAN}网络连接统计:${NC}"
        netstat -tuln 2>/dev/null | wc -l | xargs -I {} echo -e "${CYAN}活动连接数:${NC} ${BOLD_GREEN}{}${NC}"
        echo ""
        echo -e "${BOLD_CYAN}监听端口:${NC}"
        netstat -tlnp 2>/dev/null | head -10
        echo ""
        echo -e "${BOLD_CYAN}网络接口流量:${NC}"
        if command -v ip &> /dev/null; then
          ip -s link show | head -20
        fi
        pause
        ;;
      0) return ;;
      *) error "无效选项"; pause ;;
    esac
  done
}

# ---------- DNS配置管理 ----------
dns_management() {
  while true; do
    clear
    print_menu_header "DNS 配置管理"

    echo -e "${BOLD_CYAN}当前 DNS 配置:${NC}"
    print_separator
    if [ -f /etc/resolv.conf ]; then
      cat /etc/resolv.conf
    else
      warn "未找到 resolv.conf 文件"
    fi
    echo ""

    echo -e "${BOLD_YELLOW}请选择操作:${NC}"
    print_option "1" "切换到阿里云 DNS"
    print_option "2" "切换到腾讯云 DNS"
    print_option "3" "切换到华为云 DNS"
    print_option "4" "切换到 Google DNS"
    print_option "5" "切换到 Cloudflare DNS"
    print_option "6" "自定义 DNS"
    print_option "7" "恢复默认 DNS"
    print_separator
    echo -e "  ${BOLD_RED}0)${NC} ${RED}返回主菜单${NC}"
    print_separator
    echo -ne "${BOLD_MAGENTA}请选择: ${NC}"
    read -r choice

    case $choice in
      1)
        info "切换到阿里云 DNS..."
        configure_dns "223.5.5.5" "223.6.6.6"
        ;;
      2)
        info "切换到腾讯云 DNS..."
        configure_dns "119.28.28.28" "182.254.116.116"
        ;;
      3)
        info "切换到华为云 DNS..."
        configure_dns "122.112.208.1" "122.112.208.2"
        ;;
      4)
        info "切换到 Google DNS..."
        configure_dns "8.8.8.8" "8.8.4.4"
        ;;
      5)
        info "切换到 Cloudflare DNS..."
        configure_dns "1.1.1.1" "1.0.0.1"
        ;;
      6)
        question "请输入主 DNS 服务器: "
        read -r primary_dns
        question "请输入备 DNS 服务器 (可选): "
        read -r secondary_dns
        if [ -n "$primary_dns" ]; then
          configure_dns "$primary_dns" "$secondary_dns"
        else
          error "主 DNS 服务器不能为空"
          pause
          continue
        fi
        ;;
      7)
        info "恢复系统默认 DNS..."
        # 尝试恢复原始配置
        if [ -f /etc/resolv.conf.backup ]; then
          cp /etc/resolv.conf.backup /etc/resolv.conf
          success "已恢复原始 DNS 配置"
        else
          # 设置一些常见的默认 DNS
          configure_dns "8.8.8.8" "8.8.4.4"
          success "已设置为默认 DNS (Google)"
        fi
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac

    if [[ $choice =~ ^[1-6]$ ]]; then
      echo "✅ DNS 配置已更新"
      echo "测试新 DNS 配置..."
      if command -v nslookup &> /dev/null; then
        nslookup google.com 2>/dev/null | head -5
      fi
      pause
    fi
  done
}

# 配置 DNS 服务器
configure_dns() {
  local primary="$1"
  local secondary="$2"

  # 备份当前配置
  [ ! -f /etc/resolv.conf.backup ] && cp /etc/resolv.conf /etc/resolv.conf.backup

  # 创建新的 resolv.conf
  cat > /etc/resolv.conf << EOF
# Generated by txrui.sh
nameserver $primary
EOF

  if [ -n "$secondary" ]; then
    echo "nameserver $secondary" >> /etc/resolv.conf
  fi

  echo "options timeout:2 attempts:3 rotate" >> /etc/resolv.conf
}

# ---------- Docker管理 ----------
docker_management() {
  while true; do
    clear
    echo "=========================================="
    echo "         Docker 管理工具"
    echo "=========================================="

    if command -v docker &> /dev/null; then
      echo "🐳 Docker 已安装"
      echo "版本: $(docker --version 2>/dev/null || echo '未知')"
      echo "状态: $(systemctl is-active docker 2>/dev/null || echo '未知')"
    else
      echo "❌ Docker 未安装"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 安装 Docker"
    echo "2) 卸载 Docker"
    echo "3) 启动 Docker 服务"
    echo "4) 停止 Docker 服务"
    echo "5) 重启 Docker 服务"
    echo "6) 查看 Docker 状态"
    echo "7) 配置 Docker 加速源"
    echo "8) Docker 清理工具"
    echo "9) 查看运行中的容器"
    echo "10) 查看所有容器"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "安装 Docker..."
        if command -v docker &> /dev/null; then
          echo "Docker 已经安装"
        else
          # 检测系统类型并安装 Docker
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update
            apt install -y docker-ce docker-ce-cli containerd.io
          elif [ -f /etc/redhat-release ]; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
          fi

          systemctl enable docker
          systemctl start docker
          usermod -aG docker $USER 2>/dev/null || true
          echo "✅ Docker 安装完成"
        fi
        pause
        ;;
      2)
        echo "卸载 Docker..."
        if command -v docker &> /dev/null; then
          systemctl stop docker 2>/dev/null
          if [ -f /etc/debian_version ]; then
            apt purge -y docker-ce docker-ce-cli containerd.io
            apt autoremove -y
          elif [ -f /etc/redhat-release ]; then
            yum remove -y docker-ce docker-ce-cli containerd.io
          fi
          rm -rf /var/lib/docker
          rm -rf /etc/docker
          echo "✅ Docker 已卸载"
        else
          echo "Docker 未安装"
        fi
        pause
        ;;
      3)
        echo "启动 Docker 服务..."
        systemctl start docker && echo "✅ Docker 服务已启动" || echo "❌ 启动失败"
        pause
        ;;
      4)
        echo "停止 Docker 服务..."
        systemctl stop docker && echo "✅ Docker 服务已停止" || echo "❌ 停止失败"
        pause
        ;;
      5)
        echo "重启 Docker 服务..."
        systemctl restart docker && echo "✅ Docker 服务已重启" || echo "❌ 重启失败"
        pause
        ;;
      6)
        echo "Docker 状态信息:"
        docker info 2>/dev/null || echo "无法获取 Docker 信息"
        echo ""
        echo "Docker 服务状态:"
        systemctl status docker --no-pager -l 2>/dev/null || echo "无法获取服务状态"
        pause
        ;;
      7)
        echo "配置 Docker 加速源..."
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://registry.docker-cn.com"
  ]
}
EOF
        systemctl daemon-reload
        systemctl restart docker
        echo "✅ Docker 加速源已配置"
        pause
        ;;
      8)
        echo "Docker 清理工具..."
        echo "清理停止的容器..."
        docker container prune -f
        echo "清理未使用的镜像..."
        docker image prune -f
        echo "清理未使用的网络..."
        docker network prune -f
        echo "清理未使用的卷..."
        docker volume prune -f
        echo "清理构建缓存..."
        docker builder prune -f
        echo "系统级清理..."
        docker system prune -f
        echo "✅ Docker 清理完成"
        pause
        ;;
      9)
        echo "运行中的容器:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        pause
        ;;
      10)
        echo "所有容器:"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- 数据库管理 ----------
database_management() {
  while true; do
    clear
    echo "=========================================="
    echo "         数据库管理工具"
    echo "=========================================="

    # 检测已安装的数据库
    local mysql_installed=false
    local pgsql_installed=false

    if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
      mysql_installed=true
      echo "🗄️  MySQL/MariaDB: 已安装"
    fi

    if command -v psql &> /dev/null; then
      pgsql_installed=true
      echo "🗄️  PostgreSQL: 已安装"
    fi

    if [ "$mysql_installed" = false ] && [ "$pgsql_installed" = false ]; then
      echo "❌ 未检测到已安装的数据库"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 安装 MySQL"
    echo "2) 安装 PostgreSQL"
    echo "3) 卸载 MySQL"
    echo "4) 卸载 PostgreSQL"
    echo "5) MySQL 数据库备份"
    echo "6) PostgreSQL 数据库备份"
    echo "7) MySQL 数据库恢复"
    echo "8) PostgreSQL 数据库恢复"
    echo "9) 查看数据库状态"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "安装 MySQL..."
        if [ "$mysql_installed" = true ]; then
          echo "MySQL 已安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y mysql-server
          elif [ -f /etc/redhat-release ]; then
            yum install -y mysql-server
          fi
          systemctl enable mysql 2>/dev/null || systemctl enable mariadb 2>/dev/null
          systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null
          echo "✅ MySQL 安装完成"
          echo "默认密码为空，请运行: sudo mysql_secure_installation"
        fi
        pause
        ;;
      2)
        echo "安装 PostgreSQL..."
        if [ "$pgsql_installed" = true ]; then
          echo "PostgreSQL 已安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y postgresql postgresql-contrib
          elif [ -f /etc/redhat-release ]; then
            yum install -y postgresql-server postgresql-contrib
            postgresql-setup initdb 2>/dev/null || true
          fi
          systemctl enable postgresql
          systemctl start postgresql
          echo "✅ PostgreSQL 安装完成"
        fi
        pause
        ;;
      3)
        echo "卸载 MySQL..."
        if [ "$mysql_installed" = true ]; then
          systemctl stop mysql 2>/dev/null || systemctl stop mariadb 2>/dev/null
          if [ -f /etc/debian_version ]; then
            apt purge -y mysql-server mysql-client mysql-common mysql-server-core-*
            apt autoremove -y
          elif [ -f /etc/redhat-release ]; then
            yum remove -y mysql-server
          fi
          rm -rf /var/lib/mysql
          echo "✅ MySQL 已卸载"
        else
          echo "MySQL 未安装"
        fi
        pause
        ;;
      4)
        echo "卸载 PostgreSQL..."
        if [ "$pgsql_installed" = true ]; then
          systemctl stop postgresql
          if [ -f /etc/debian_version ]; then
            apt purge -y postgresql postgresql-contrib
            apt autoremove -y
          elif [ -f /etc/redhat-release ]; then
            yum remove -y postgresql-server postgresql-contrib
          fi
          rm -rf /var/lib/pgsql
          echo "✅ PostgreSQL 已卸载"
        else
          echo "PostgreSQL 未安装"
        fi
        pause
        ;;
      5)
        echo "MySQL 数据库备份..."
        if [ "$mysql_installed" = true ]; then
          read -rp "请输入数据库用户名 (默认: root): " db_user
          db_user=${db_user:-root}
          read -rp "请输入数据库密码: " -s db_pass
          echo ""
          read -rp "请输入要备份的数据库名 (留空备份所有): " db_name
          backup_file="/root/mysql_backup_$(date +%Y%m%d_%H%M%S).sql"

          if [ -z "$db_name" ]; then
            mysqldump -u"$db_user" -p"$db_pass" --all-databases > "$backup_file" 2>/dev/null && echo "✅ 所有数据库已备份到: $backup_file" || echo "❌ 备份失败"
          else
            mysqldump -u"$db_user" -p"$db_pass" "$db_name" > "$backup_file" 2>/dev/null && echo "✅ 数据库 $db_name 已备份到: $backup_file" || echo "❌ 备份失败"
          fi
        else
          echo "MySQL 未安装"
        fi
        pause
        ;;
      6)
        echo "PostgreSQL 数据库备份..."
        if [ "$pgsql_installed" = true ]; then
          read -rp "请输入要备份的数据库名 (默认: postgres): " db_name
          db_name=${db_name:-postgres}
          backup_file="/root/postgres_backup_$(date +%Y%m%d_%H%M%S).sql"

          sudo -u postgres pg_dump "$db_name" > "$backup_file" 2>/dev/null && echo "✅ 数据库 $db_name 已备份到: $backup_file" || echo "❌ 备份失败"
        else
          echo "PostgreSQL 未安装"
        fi
        pause
        ;;
      7)
        echo "MySQL 数据库恢复..."
        if [ "$mysql_installed" = true ]; then
          read -rp "请输入备份文件路径: " backup_file
          if [ -f "$backup_file" ]; then
            read -rp "请输入数据库用户名 (默认: root): " db_user
            db_user=${db_user:-root}
            read -rp "请输入数据库密码: " -s db_pass
            echo ""
            mysql -u"$db_user" -p"$db_pass" < "$backup_file" 2>/dev/null && echo "✅ 数据库恢复完成" || echo "❌ 恢复失败"
          else
            echo "❌ 备份文件不存在"
          fi
        else
          echo "MySQL 未安装"
        fi
        pause
        ;;
      8)
        echo "PostgreSQL 数据库恢复..."
        if [ "$pgsql_installed" = true ]; then
          read -rp "请输入备份文件路径: " backup_file
          if [ -f "$backup_file" ]; then
            read -rp "请输入要恢复的数据库名: " db_name
            if [ -n "$db_name" ]; then
              sudo -u postgres psql -c "CREATE DATABASE $db_name;" 2>/dev/null || true
              sudo -u postgres psql "$db_name" < "$backup_file" 2>/dev/null && echo "✅ 数据库恢复完成" || echo "❌ 恢复失败"
            else
              echo "❌ 数据库名不能为空"
            fi
          else
            echo "❌ 备份文件不存在"
          fi
        else
          echo "PostgreSQL 未安装"
        fi
        pause
        ;;
      9)
        echo "数据库状态信息:"
        if [ "$mysql_installed" = true ]; then
          echo "MySQL 状态:"
          systemctl status mysql --no-pager -l 2>/dev/null || systemctl status mariadb --no-pager -l 2>/dev/null || echo "无法获取状态"
          echo ""
        fi
        if [ "$pgsql_installed" = true ]; then
          echo "PostgreSQL 状态:"
          systemctl status postgresql --no-pager -l 2>/dev/null || echo "无法获取状态"
        fi
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- Python环境管理 ----------
python_management() {
  while true; do
    clear
    echo "=========================================="
    echo "         Python 环境管理"
    echo "=========================================="

    # 检测Python版本
    if command -v python3 &> /dev/null; then
      python_version=$(python3 --version 2>&1 | awk '{print $2}')
      echo "🐍 Python3: 已安装 (版本: $python_version)"
    else
      echo "❌ Python3: 未安装"
    fi

    if command -v python2 &> /dev/null; then
      python2_version=$(python2 --version 2>&1 | awk '{print $2}')
      echo "🐍 Python2: 已安装 (版本: $python2_version)"
    fi

    if command -v pip3 &> /dev/null; then
      pip_version=$(pip3 --version 2>&1 | head -1 | awk '{print $2}')
      echo "📦 pip3: 已安装 (版本: $pip_version)"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 安装 Python3"
    echo "2) 安装 Python2"
    echo "3) 升级 Python3"
    echo "4) 卸载 Python3"
    echo "5) 安装 pip"
    echo "6) 升级 pip"
    echo "7) 配置 pip 源"
    echo "8) 清理 Python 缓存"
    echo "9) 查看已安装的包"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "安装 Python3..."
        if command -v python3 &> /dev/null; then
          echo "Python3 已经安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y python3 python3-dev python3-pip
          elif [ -f /etc/redhat-release ]; then
            yum install -y python3 python3-devel python3-pip
          fi
          echo "✅ Python3 安装完成"
        fi
        pause
        ;;
      2)
        echo "安装 Python2..."
        if command -v python2 &> /dev/null; then
          echo "Python2 已经安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y python2 python2-dev python-pip
          elif [ -f /etc/redhat-release ]; then
            yum install -y python2 python2-devel python-pip
          fi
          echo "✅ Python2 安装完成"
        fi
        pause
        ;;
      3)
        echo "升级 Python3..."
        if command -v python3 &> /dev/null; then
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y python3 python3-dev --only-upgrade
          elif [ -f /etc/redhat-release ]; then
            yum update -y python3 python3-devel
          fi
          echo "✅ Python3 升级完成"
        else
          echo "Python3 未安装，请先安装"
        fi
        pause
        ;;
      4)
        echo "卸载 Python3..."
        if command -v python3 &> /dev/null; then
          read -rp "确定要卸载 Python3 吗? 这可能影响系统功能 (y/N): " confirm
          if [[ $confirm =~ ^[Yy]$ ]]; then
            if [ -f /etc/debian_version ]; then
              apt purge -y python3 python3-dev python3-pip
              apt autoremove -y
            elif [ -f /etc/redhat-release ]; then
              yum remove -y python3 python3-devel python3-pip
            fi
            echo "✅ Python3 已卸载"
          fi
        else
          echo "Python3 未安装"
        fi
        pause
        ;;
      5)
        echo "安装 pip..."
        if command -v pip3 &> /dev/null; then
          echo "pip3 已经安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y python3-pip
          elif [ -f /etc/redhat-release ]; then
            yum install -y python3-pip
          fi
          echo "✅ pip 安装完成"
        fi
        pause
        ;;
      6)
        echo "升级 pip..."
        if command -v pip3 &> /dev/null; then
          python3 -m pip install --upgrade pip && echo "✅ pip 升级完成" || echo "❌ pip 升级失败"
        else
          echo "pip 未安装，请先安装"
        fi
        pause
        ;;
      7)
        echo "配置 pip 源..."
        mkdir -p ~/.pip
        cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
[install]
trusted-host = https://pypi.tuna.tsinghua.edu.cn
EOF
        echo "✅ pip 源已配置为清华大学镜像"
        pause
        ;;
      8)
        echo "清理 Python 缓存..."
        # 清理 pip 缓存
        if command -v pip3 &> /dev/null; then
          pip3 cache purge 2>/dev/null && echo "✅ pip 缓存已清理" || echo "⚠️ pip 缓存清理失败"
        fi

        # 清理 __pycache__ 目录
        find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null && echo "✅ __pycache__ 目录已清理" || true

        # 清理 .pyc 文件
        find . -type f -name "*.pyc" -delete 2>/dev/null && echo "✅ .pyc 文件已清理" || true

        echo "✅ Python 缓存清理完成"
        pause
        ;;
      9)
        echo "已安装的 Python 包:"
        if command -v pip3 &> /dev/null; then
          pip3 list --format=columns
        else
          echo "pip 未安装"
        fi
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- Fail2Ban管理 ----------
fail2ban_management() {
  while true; do
    clear
    echo "=========================================="
    echo "         Fail2Ban 管理工具"
    echo "=========================================="

    if command -v fail2ban-server &> /dev/null; then
      echo "🛡️  Fail2Ban: 已安装"
      echo "状态: $(systemctl is-active fail2ban 2>/dev/null || echo '未知')"
    else
      echo "❌ Fail2Ban: 未安装"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 安装 Fail2Ban"
    echo "2) 卸载 Fail2Ban"
    echo "3) 启动 Fail2Ban"
    echo "4) 停止 Fail2Ban"
    echo "5) 重启 Fail2Ban"
    echo "6) 查看状态"
    echo "7) 查看封禁列表"
    echo "8) 解禁IP"
    echo "9) 配置SSH防护"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "安装 Fail2Ban..."
        if command -v fail2ban-server &> /dev/null; then
          echo "Fail2Ban 已经安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y fail2ban
          elif [ -f /etc/redhat-release ]; then
            yum install -y fail2ban
          fi
          systemctl enable fail2ban
          systemctl start fail2ban
          echo "✅ Fail2Ban 安装完成"
        fi
        pause
        ;;
      2)
        echo "卸载 Fail2Ban..."
        if command -v fail2ban-server &> /dev/null; then
          systemctl stop fail2ban
          if [ -f /etc/debian_version ]; then
            apt purge -y fail2ban
            apt autoremove -y
          elif [ -f /etc/redhat-release ]; then
            yum remove -y fail2ban
          fi
          echo "✅ Fail2Ban 已卸载"
        else
          echo "Fail2Ban 未安装"
        fi
        pause
        ;;
      3)
        systemctl start fail2ban && echo "✅ Fail2Ban 已启动" || echo "❌ 启动失败"
        pause
        ;;
      4)
        systemctl stop fail2ban && echo "✅ Fail2Ban 已停止" || echo "❌ 停止失败"
        pause
        ;;
      5)
        systemctl restart fail2ban && echo "✅ Fail2Ban 已重启" || echo "❌ 重启失败"
        pause
        ;;
      6)
        echo "Fail2Ban 状态:"
        fail2ban-client status 2>/dev/null || echo "无法获取状态"
        echo ""
        echo "SSH 监狱状态:"
        fail2ban-client status sshd 2>/dev/null || echo "无法获取SSH监狱状态"
        pause
        ;;
      7)
        echo "当前封禁的IP列表:"
        fail2ban-client status sshd 2>/dev/null | grep "Banned IP list:" -A 10 | sed 's/Banned IP list://g' | tr -d '\n' | sed 's/ /\n/g' | grep -v '^$' | head -20 || echo "无法获取封禁列表"
        pause
        ;;
      8)
        read -rp "请输入要解禁的IP地址: " unban_ip
        if [ -n "$unban_ip" ]; then
          fail2ban-client set sshd unbanip "$unban_ip" 2>/dev/null && echo "✅ IP $unban_ip 已解禁" || echo "❌ 解禁失败"
        else
          echo "❌ IP地址不能为空"
        fi
        pause
        ;;
      9)
        echo "配置SSH防护..."
        # 创建自定义的jail配置
        cat > /etc/fail2ban/jail.d/sshd-custom.conf << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
        systemctl restart fail2ban
        echo "✅ SSH防护配置已更新"
        echo "封禁规则: 10分钟内失败3次，封禁1小时"
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- SSL证书续签助手 ----------
ssl_certificate_helper() {
  while true; do
    clear
    echo "=========================================="
    echo "         SSL证书续签助手"
    echo "=========================================="

    if command -v certbot &> /dev/null; then
      echo "🔐 Certbot: 已安装"
    else
      echo "❌ Certbot: 未安装"
    fi

    if command -v acme.sh &> /dev/null; then
      echo "🔐 acme.sh: 已安装"
    else
      echo "❌ acme.sh: 未安装"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 安装 Certbot"
    echo "2) 安装 acme.sh"
    echo "3) 使用Certbot申请证书"
    echo "4) 使用acme.sh申请证书"
    echo "5) 续签所有证书"
    echo "6) 查看证书状态"
    echo "7) 删除证书"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "安装 Certbot..."
        if command -v certbot &> /dev/null; then
          echo "Certbot 已经安装"
        else
          if [ -f /etc/debian_version ]; then
            apt update
            apt install -y certbot python3-certbot-nginx python3-certbot-apache
          elif [ -f /etc/redhat-release ]; then
            yum install -y certbot python3-certbot-nginx python3-certbot-apache
          fi
          echo "✅ Certbot 安装完成"
        fi
        pause
        ;;
      2)
        echo "安装 acme.sh..."
        if command -v acme.sh &> /dev/null; then
          echo "acme.sh 已经安装"
        else
          curl https://get.acme.sh | sh
          source ~/.bashrc
          echo "✅ acme.sh 安装完成"
        fi
        pause
        ;;
      3)
        echo "使用Certbot申请证书..."
        if command -v certbot &> /dev/null; then
          echo "请选择认证方式:"
          echo "1) 独立服务器 (standalone)"
          echo "2) Nginx"
          echo "3) Apache"
          read -rp "请选择 [1-3]: " auth_type

          read -rp "请输入域名 (多个域名用空格分隔): " domains
          read -rp "请输入邮箱: " email

          case $auth_type in
            1) certbot certonly --standalone -d $domains --email $email --agree-tos --non-interactive ;;
            2) certbot --nginx -d $domains --email $email --agree-tos --non-interactive ;;
            3) certbot --apache -d $domains --email $email --agree-tos --non-interactive ;;
            *) echo "❌ 无效选择"; return ;;
          esac

          if [ $? -eq 0 ]; then
            echo "✅ 证书申请成功"
            echo "证书位置: /etc/letsencrypt/live/$domains/"
          else
            echo "❌ 证书申请失败"
          fi
        else
          echo "Certbot 未安装"
        fi
        pause
        ;;
      4)
        echo "使用acme.sh申请证书..."
        if command -v acme.sh &> /dev/null; then
          read -rp "请输入域名: " domain
          read -rp "请输入邮箱: " email

          acme.sh --issue --standalone -d $domain --email $email
          if [ $? -eq 0 ]; then
            echo "✅ 证书申请成功"
            acme.sh --install-cert -d $domain --key-file /etc/ssl/private/$domain.key --fullchain-file /etc/ssl/certs/$domain.crt
            echo "证书已安装到 /etc/ssl/"
          else
            echo "❌ 证书申请失败"
          fi
        else
          echo "acme.sh 未安装"
        fi
        pause
        ;;
      5)
        echo "续签所有证书..."
        renewed=0
        if command -v certbot &> /dev/null; then
          certbot renew && ((renewed++)) && echo "✅ Certbot证书续签完成"
        fi
        if command -v acme.sh &> /dev/null; then
          acme.sh --cron && ((renewed++)) && echo "✅ acme.sh证书续签完成"
        fi
        if [ $renewed -eq 0 ]; then
          echo "❌ 未找到可用的证书管理工具"
        fi
        pause
        ;;
      6)
        echo "证书状态:"
        if command -v certbot &> /dev/null; then
          echo "Certbot 证书:"
          certbot certificates 2>/dev/null || echo "无Certbot证书"
          echo ""
        fi

        if command -v acme.sh &> /dev/null; then
          echo "acme.sh 证书:"
          acme.sh --list || echo "无acme.sh证书"
        fi

        # 检查常见的证书位置
        echo ""
        echo "系统证书文件:"
        find /etc/letsencrypt/live -name "*.pem" 2>/dev/null | head -10 || echo "未找到Let's Encrypt证书"
        find /etc/ssl -name "*.crt" 2>/dev/null | head -10 || echo "未找到SSL证书文件"
        pause
        ;;
      7)
        echo "删除证书..."
        echo "1) 删除Certbot证书"
        echo "2) 删除acme.sh证书"
        read -rp "请选择 [1-2]: " del_type

        case $del_type in
          1)
            if command -v certbot &> /dev/null; then
              certbot certificates
              read -rp "请输入要删除的域名: " domain
              certbot delete --cert-name $domain && echo "✅ 证书已删除" || echo "❌ 删除失败"
            else
              echo "Certbot 未安装"
            fi
            ;;
          2)
            if command -v acme.sh &> /dev/null; then
              acme.sh --list
              read -rp "请输入要删除的域名: " domain
              acme.sh --remove -d $domain && echo "✅ 证书已删除" || echo "❌ 删除失败"
            else
              echo "acme.sh 未安装"
            fi
            ;;
        esac
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- GitHub加速 ----------
github_acceleration() {
  while true; do
    clear
    echo "=========================================="
    echo "         GitHub 加速配置"
    echo "=========================================="

    echo "GitHub 加速可以提高访问速度和克隆仓库效率"
    echo ""

    echo "请选择加速方式:"
    echo "1) 配置 Hosts 加速"
    echo "2) 配置 Git 代理"
    echo "3) 使用 GitHub 镜像站点"
    echo "4) 配置 SSH 密钥认证"
    echo "5) 查看当前配置"
    echo "6) 恢复默认配置"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "配置 Hosts 加速..."
        # 备份当前hosts
        cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

        # 添加GitHub的IP映射
        cat >> /etc/hosts << 'EOF'

# GitHub Hosts 加速
140.82.112.3 github.com
140.82.112.3 www.github.com
185.199.108.153 assets-cdn.github.com
185.199.108.153 github.global.ssl.fastly.net
199.232.68.133 raw.githubusercontent.com
199.232.68.133 gist.githubusercontent.com
199.232.68.133 cloud.githubusercontent.com
199.232.68.133 camo.githubusercontent.com
199.232.68.133 avatars.githubusercontent.com
199.232.68.133 avatars0.githubusercontent.com
199.232.68.133 avatars1.githubusercontent.com
199.232.68.133 avatars2.githubusercontent.com
199.232.68.133 avatars3.githubusercontent.com
199.232.68.133 avatars4.githubusercontent.com
199.232.68.133 avatars5.githubusercontent.com
199.232.68.133 avatars6.githubusercontent.com
199.232.68.133 avatars7.githubusercontent.com
199.232.68.133 avatars8.githubusercontent.com
EOF
        echo "✅ GitHub Hosts 加速配置完成"
        echo "注意: IP地址可能随时间变化，如访问异常请更新"
        pause
        ;;
      2)
        echo "配置 Git 代理..."
        read -rp "请输入代理地址 (格式: http://proxy:port 或 socks5://proxy:port): " proxy_url
        if [ -n "$proxy_url" ]; then
          git config --global http.proxy "$proxy_url"
          git config --global https.proxy "$proxy_url"
          echo "✅ Git 代理已配置"
        else
          echo "❌ 代理地址不能为空"
        fi
        pause
        ;;
      3)
        echo "配置 GitHub 镜像站点..."
        echo "选择镜像站点:"
        echo "1) 清华大学 (https://mirrors.tuna.tsinghua.edu.cn/git/github.com)"
        echo "2) 中国科学技术大学 (https://github.com.cnpmjs.org)"
        echo "3) 上海交通大学 (https://git.sjtu.edu.cn)"
        read -rp "请选择镜像站点 [1-3]: " mirror_choice

        case $mirror_choice in
          1)
            git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/github.com".insteadOf "https://github.com"
            echo "✅ 已配置清华大学镜像"
            ;;
          2)
            git config --global url."https://github.com.cnpmjs.org".insteadOf "https://github.com"
            echo "✅ 已配置中科院镜像"
            ;;
          3)
            git config --global url."https://git.sjtu.edu.cn".insteadOf "https://github.com"
            echo "✅ 已配置上海交大镜像"
            ;;
          *) echo "❌ 无效选择" ;;
        esac
        pause
        ;;
      4)
        echo "配置 SSH 密钥认证..."
        if [ ! -f ~/.ssh/id_rsa ]; then
          echo "生成 SSH 密钥..."
          ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        fi

        echo "SSH 公钥内容 (添加到 GitHub SSH Keys 中):"
        echo "=========================================="
        cat ~/.ssh/id_rsa.pub
        echo "=========================================="
        echo ""
        echo "配置步骤:"
        echo "1. 复制上面的公钥内容"
        echo "2. 登录 GitHub.com"
        echo "3. 进入 Settings > SSH and GPG keys"
        echo "4. 点击 'New SSH key'"
        echo "5. 粘贴公钥并保存"
        echo ""
        echo "测试连接: ssh -T git@github.com"
        pause
        ;;
      5)
        echo "当前 GitHub 加速配置:"
        echo ""

        echo "Git 全局配置:"
        git config --global --list | grep -E "(proxy|insteadOf|github)" || echo "无相关配置"

        echo ""
        echo "SSH 配置:"
        if [ -f ~/.ssh/id_rsa.pub ]; then
          echo "✅ SSH 密钥已生成"
          ssh -T git@github.com 2>&1 | head -3 || echo "SSH 连接未测试"
        else
          echo "❌ SSH 密钥未生成"
        fi

        echo ""
        echo "/etc/hosts 中的 GitHub 配置:"
        grep -E "(github|assets-cdn)" /etc/hosts || echo "无相关配置"

        pause
        ;;
      6)
        echo "恢复默认配置..."
        # 恢复git配置
        git config --global --unset-all http.proxy 2>/dev/null || true
        git config --global --unset-all https.proxy 2>/dev/null || true
        git config --global --remove-section url 2>/dev/null || true

        # 恢复hosts（保留备份）
        if [ -f /etc/hosts.backup.* ]; then
          latest_backup=$(ls -t /etc/hosts.backup.* | head -1)
          cp "$latest_backup" /etc/hosts
          echo "✅ Hosts 文件已恢复"
        fi

        echo "✅ GitHub 加速配置已重置"
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- SSH端口修改 ----------
ssh_port_modification() {
  clear
  echo "=========================================="
  echo "         SSH 端口修改工具"
  echo "=========================================="

  current_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
  echo "当前 SSH 端口: $current_port"
  echo ""

  read -rp "请输入新的 SSH 端口 (推荐: 10000-65535): " new_port

  # 验证端口号
  if ! [[ $new_port =~ ^[0-9]+$ ]] || [ $new_port -lt 1 ] || [ $new_port -gt 65535 ]; then
    echo "❌ 无效端口号，请输入 1-65535 之间的数字"
    pause
    return
  fi

  # 检查端口是否被占用
  if netstat -tln 2>/dev/null | grep ":$new_port " > /dev/null; then
    echo "❌ 端口 $new_port 已被占用"
    pause
    return
  fi

  # 备份配置文件
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

  # 修改端口
  if grep -q "^Port" /etc/ssh/sshd_config; then
    sed -i "s/^Port.*/Port $new_port/" /etc/ssh/sshd_config
  else
    echo "Port $new_port" >> /etc/ssh/sshd_config
  fi

  # 配置防火墙
  if command -v ufw &> /dev/null; then
    ufw allow $new_port/tcp 2>/dev/null || true
    ufw delete allow $current_port/tcp 2>/dev/null || true
    echo "✅ UFW 防火墙已更新"
  elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=$new_port/tcp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=$current_port/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "✅ Firewalld 已更新"
  fi

  # 重启SSH服务
  systemctl restart sshd && echo "✅ SSH 服务重启成功" || echo "⚠️ SSH 服务重启失败，请手动检查"

  echo ""
  echo "🎉 SSH 端口已修改为: $new_port"
  echo "🔴 重要提醒:"
  echo "1. 请使用新端口连接: ssh -p $new_port user@host"
  echo "2. 确认新连接正常后再关闭旧连接"
  echo "3. 更新防火墙规则和任何相关的配置"
  echo "4. 备份文件位置: /etc/ssh/sshd_config.backup.*"

  pause
}

# ---------- ICMP响应控制 ----------
icmp_control() {
  while true; do
    clear
    echo "=========================================="
    echo "         ICMP 响应控制"
    echo "=========================================="

    current_setting=$(sysctl -n net.ipv4.icmp_echo_ignore_all 2>/dev/null || echo "unknown")
    if [ "$current_setting" = "0" ]; then
      echo "当前状态: ✅ ICMP 响应已开启 (允许ping)"
    elif [ "$current_setting" = "1" ]; then
      echo "当前状态: ❌ ICMP 响应已关闭 (禁止ping)"
    else
      echo "当前状态: ❓ 无法检测"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 开启 ICMP 响应 (允许ping)"
    echo "2) 关闭 ICMP 响应 (禁止ping)"
    echo "3) 临时开启 (仅当前会话)"
    echo "4) 临时关闭 (仅当前会话)"
    echo "5) 查看 ICMP 相关设置"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        sysctl -w net.ipv4.icmp_echo_ignore_all=0
        echo "net.ipv4.icmp_echo_ignore_all=0" > /etc/sysctl.d/99-icmp.conf
        sysctl -p /etc/sysctl.d/99-icmp.conf
        echo "✅ ICMP 响应已永久开启"
        pause
        ;;
      2)
        sysctl -w net.ipv4.icmp_echo_ignore_all=1
        echo "net.ipv4.icmp_echo_ignore_all=1" > /etc/sysctl.d/99-icmp.conf
        sysctl -p /etc/sysctl.d/99-icmp.conf
        echo "✅ ICMP 响应已永久关闭"
        pause
        ;;
      3)
        sysctl -w net.ipv4.icmp_echo_ignore_all=0
        echo "✅ ICMP 响应已临时开启 (重启后失效)"
        pause
        ;;
      4)
        sysctl -w net.ipv4.icmp_echo_ignore_all=1
        echo "✅ ICMP 响应已临时关闭 (重启后失效)"
        pause
        ;;
      5)
        echo "ICMP 相关设置:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        sysctl -a | grep icmp || echo "无相关设置"
        echo ""
        echo "防火墙 ICMP 设置:"
        if command -v ufw &> /dev/null; then
            ufw status | grep icmp || echo "UFW: 无ICMP规则"
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --list-all | grep icmp || echo "Firewalld: 无ICMP规则"
        else
            echo "未检测到防火墙"
        fi
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- NTP时间同步 ----------
ntp_sync() {
  while true; do
    clear
    echo "=========================================="
    echo "         NTP 时间同步"
    echo "=========================================="

    current_time=$(date)
    echo "当前系统时间: $current_time"

    if command -v timedatectl &> /dev/null; then
      echo "NTP 状态: $(timedatectl show --property=NTP --value)"
      echo "时间同步: $(timedatectl show --property=NTPSynchronized --value)"
    fi
    echo ""

    echo "请选择操作:"
    echo "1) 安装 NTP 服务"
    echo "2) 同步时间 (立即)"
    echo "3) 启用 NTP 自动同步"
    echo "4) 禁用 NTP 自动同步"
    echo "5) 配置 NTP 服务器"
    echo "6) 查看时间状态"
    echo "7) 手动设置时间"
    echo "0) 返回主菜单"
    echo "------------------------------------------"
    read -rp "请选择: " choice

    case $choice in
      1)
        echo "安装 NTP 服务..."
        if command -v apt &> /dev/null; then
          apt update && apt install -y ntp ntpdate
        elif command -v yum &> /dev/null; then
          yum install -y ntp ntpdate
        fi

        if command -v timedatectl &> /dev/null; then
          timedatectl set-ntp true
        else
          systemctl enable ntpd 2>/dev/null || systemctl enable ntp 2>/dev/null
          systemctl start ntpd 2>/dev/null || systemctl start ntp 2>/dev/null
        fi
        echo "✅ NTP 服务安装完成"
        pause
        ;;
      2)
        echo "同步时间..."
        if command -v ntpdate &> /dev/null; then
          ntpdate -u pool.ntp.org && echo "✅ 时间同步完成" || echo "❌ 时间同步失败"
        elif command -v timedatectl &> /dev/null; then
          timedatectl set-ntp true
          sleep 2
          echo "✅ NTP 同步已启用"
        else
          echo "❌ 未找到时间同步工具"
        fi
        pause
        ;;
      3)
        echo "启用 NTP 自动同步..."
        if command -v timedatectl &> /dev/null; then
          timedatectl set-ntp true && echo "✅ NTP 自动同步已启用"
        else
          systemctl enable ntpd 2>/dev/null || systemctl enable ntp 2>/dev/null
          systemctl start ntpd 2>/dev/null || systemctl start ntp 2>/dev/null
          echo "✅ NTP 服务已启用"
        fi
        pause
        ;;
      4)
        echo "禁用 NTP 自动同步..."
        if command -v timedatectl &> /dev/null; then
          timedatectl set-ntp false && echo "✅ NTP 自动同步已禁用"
        else
          systemctl stop ntpd 2>/dev/null || systemctl stop ntp 2>/dev/null
          systemctl disable ntpd 2>/dev/null || systemctl disable ntp 2>/dev/null
          echo "✅ NTP 服务已停止"
        fi
        pause
        ;;
      5)
        echo "配置 NTP 服务器..."
        echo "选择 NTP 服务器:"
        echo "1) pool.ntp.org (国际)"
        echo "2) cn.pool.ntp.org (中国)"
        echo "3) time.nist.gov (美国NIST)"
        echo "4) asia.pool.ntp.org (亚洲)"
        echo "5) europe.pool.ntp.org (欧洲)"
        read -rp "请选择 [1-5]: " ntp_choice

        case $ntp_choice in
          1) ntp_server="pool.ntp.org" ;;
          2) ntp_server="cn.pool.ntp.org" ;;
          3) ntp_server="time.nist.gov" ;;
          4) ntp_server="asia.pool.ntp.org" ;;
          5) ntp_server="europe.pool.ntp.org" ;;
          *) echo "❌ 无效选择"; return ;;
        esac

        # 配置NTP服务器
        if [ -f /etc/ntp.conf ]; then
          sed -i 's/^server.*/server '"$ntp_server"' iburst/g' /etc/ntp.conf
          echo "restrict default kod nomodify notrap nopeer noquery" >> /etc/ntp.conf
          echo "restrict -6 default kod nomodify notrap nopeer noquery" >> /etc/ntp.conf
        fi

        # 重启NTP服务
        systemctl restart ntpd 2>/dev/null || systemctl restart ntp 2>/dev/null || true

        echo "✅ NTP 服务器已配置为: $ntp_server"
        pause
        ;;
      6)
        echo "时间状态信息:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if command -v timedatectl &> /dev/null; then
          timedatectl status
        else
          date
          echo ""
          if command -v ntptime &> /dev/null; then
            ntptime || echo "NTP时间信息不可用"
          fi
        fi

        echo ""
        echo "NTP 配置文件 (/etc/ntp.conf):"
        if [ -f /etc/ntp.conf ]; then
          grep "^server" /etc/ntp.conf || echo "无服务器配置"
        else
          echo "NTP 配置文件不存在"
        fi
        pause
        ;;
      7)
        echo "手动设置时间..."
        read -rp "请输入时间 (格式: YYYY-MM-DD HH:MM:SS): " new_time
        if [[ $new_time =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
          date -s "$new_time" && echo "✅ 系统时间已设置为: $(date)" || echo "❌ 时间设置失败"
        else
          echo "❌ 时间格式错误，请使用 YYYY-MM-DD HH:MM:SS 格式"
        fi
        pause
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; pause ;;
    esac
  done
}

# ---------- CasaOS面板 ----------
casaos_panel() {
  clear
  echo "=========================================="
  echo "         CasaOS 面板安装"
  echo "=========================================="

  if command -v casaos &> /dev/null; then
    echo "🏠 CasaOS: 已安装"
    echo "访问地址: http://$(hostname -I | awk '{print $1}'):80"
  else
    echo "❌ CasaOS: 未安装"
  fi
  echo ""

  echo "CasaOS 是一个简单易用的家庭云系统..."
  echo ""

  warn "⚠️  安全警告: 即将执行远程安装脚本"
  echo "脚本来源: https://get.casaos.io"
  echo "此操作将从互联网下载并执行CasaOS官方安装脚本，可能会修改系统配置。"
  read -rp "确定要安装 CasaOS 吗? (y/N): " install_confirm
  if [[ $install_confirm =~ ^[Yy]$ ]]; then
    echo "开始安装 CasaOS..."

    # 官方安装脚本
    curl -fsSL https://get.casaos.io | bash

    if [ $? -eq 0 ]; then
      echo "✅ CasaOS 安装完成！"
      echo "🌐 访问地址: http://你的服务器IP:80"
      echo "👤 默认用户名: admin"
      echo "🔑 默认密码: admin"
      echo ""
      echo "首次访问会要求设置密码，请及时修改！"
    else
      echo "❌ CasaOS 安装失败"
      echo "请检查网络连接或查看官方文档: https://casaos.io/"
    fi
  else
    echo "已取消安装"
  fi

  pause
}

# ---------- 快捷工具菜单 ----------
quick_tools_menu() {
  while true; do
  clear
  echo "=========================================="
    echo "         快捷工具菜单"
  echo "=========================================="
    echo ""
    echo "【BBR优化】"
    echo "1) TCPX BBR优化             2) BBR优化脚本"
    echo ""
    echo "【面板安装】"
    echo "3) 哪吒面板                 4) 3x-ui面板"
    echo "5) h-ui面板                 6) s-ui面板"
    echo "7) MCSManager面板"
    echo ""
    echo "【网络测试】"
    echo "8) 三网回程延迟测试         9) 三网回程线路测试"
    echo "10) 三网测速脚本            11) IP质量检测"
    echo ""
    echo "【系统工具】"
    echo "12) 安装Rclone              13) 端口转发工具"
    echo "14) 安装NFS客户端           15) 查看目录占用"
    echo "16) 修改虚拟内存使用率      17) 安装基础工具包（apt）"
    echo "18) 安装基础工具包（yum）   19) 关闭宝塔面板SSL"
    echo ""
    echo "【群辉工具】"
    echo "20) 群辉查看状态            21) 群辉查看硬盘温度"
    echo "22) 群辉查看目录权限        23) 群辉修改root密码"
    echo "24) 群辉改数据块（32768）   25) 群辉恢复数据块（4096）"
    echo "26) 群辉超级权限"
    echo ""
    echo "【PVE工具】"
    echo "27) PVE一键命令             28) 进入PVE磁盘目录"
    echo ""
    echo "【系统重装】"
    echo "29) DD重装系统"
    echo ""
    echo "0) 返回主菜单"
    echo "=========================================="
    read -rp "请选择: " choice
    
    case "$choice" in
      1) install_tcpx_bbr ;;
      2) install_bbr_optimize ;;
      3) install_nezha ;;
      4) install_3xui ;;
      5) install_hui ;;
      6) install_sui ;;
      7) install_mcsmanager ;;
      8) test_besttrace ;;
      9) test_mtr_trace ;;
      10) test_superspeed ;;
      11) test_ip_quality ;;
      12) install_rclone ;;
      13) install_natcfg ;;
      14) install_nfs_client ;;
      15) show_directory_usage ;;
      16) modify_swappiness ;;
      17) install_apt_tools ;;
      18) install_yum_tools ;;
      19) disable_bt_ssl ;;
      20) synology_status ;;
      21) synology_disk_temp ;;
      22) synology_dir_permissions ;;
      23) synology_change_root_pwd ;;
      24) synology_set_stripe_32768 ;;
      25) synology_set_stripe_4096 ;;
      26) synology_super_permission ;;
      27) install_pve_source ;;
      28) enter_pve_images ;;
      29) dd_reinstall ;;
      0) return ;;
      *) error "无效选项"; pause ;;
    esac
  done
}

# ---------- BBR优化相关 ----------
install_tcpx_bbr() {
  clear
  echo "=========================================="
  echo "         TCPX BBR优化"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://github.000060000.xyz/tcpx.sh"
  echo "此操作将从互联网下载并执行脚本，可能会修改系统网络配置。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  wget -N --no-check-certificate "https://github.000060000.xyz/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
  set -e
  pause
}

install_bbr_optimize() {
  clear
  echo "=========================================="
  echo "         BBR优化脚本"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://github.com/lanziii/bbr-/releases/download/123/tools.sh"
  echo "此操作将从互联网下载并执行脚本，可能会修改系统网络配置。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -Ls https://github.com/lanziii/bbr-/releases/download/123/tools.sh)
  set -e
  pause
}

# ---------- 面板安装相关 ----------
install_nezha() {
  clear
  echo "=========================================="
  echo "         哪吒面板安装"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh"
  echo "此操作将从互联网下载并执行哪吒面板官方安装脚本。"
  read -rp "确定要安装哪吒面板吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
  set -e
  pause
}

install_3xui() {
  clear
  echo "=========================================="
  echo "         3x-ui面板安装"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh"
  echo "此操作将从互联网下载并执行3x-ui面板安装脚本。"
  read -rp "确定要安装3x-ui面板吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
  set -e
  pause
}

install_hui() {
  clear
  echo "=========================================="
  echo "         h-ui面板安装"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://raw.githubusercontent.com/jonssonyan/h-ui/main/install.sh"
  echo "此操作将从互联网下载并执行h-ui面板安装脚本。"
  read -rp "确定要安装h-ui面板吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -fsSL https://raw.githubusercontent.com/jonssonyan/h-ui/main/install.sh)
  set -e
  pause
}

install_sui() {
  clear
  echo "=========================================="
  echo "         s-ui面板安装"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh"
  echo "此操作将从互联网下载并执行s-ui面板安装脚本。"
  read -rp "确定要安装s-ui面板吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh)
  set -e
  pause
}

install_mcsmanager() {
  clear
  echo "=========================================="
  echo "       MCSManager面板安装"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://script.mcsmanager.com/setup_cn.sh"
  echo "此操作将从互联网下载并执行MCSManager面板安装脚本。"
  read -rp "确定要安装MCSManager面板吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  sudo su -c "wget -qO- https://script.mcsmanager.com/setup_cn.sh | bash"
  set -e
  pause
}

# ---------- 网络测试相关 ----------
test_besttrace() {
  clear
  echo "=========================================="
  echo "         三网回程延迟测试"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://git.io/besttrace"
  echo "此操作将从互联网下载并执行网络测试脚本。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  wget -qO- git.io/besttrace | bash
  set -e
  pause
}

test_mtr_trace() {
  clear
  echo "=========================================="
  echo "         三网回程线路测试"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh"
  echo "此操作将从互联网下载并执行网络测试脚本。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  curl https://raw.githubusercontent.com/zhucaidan/mtr_trace/main/mtr_trace.sh|bash
  set -e
  pause
}

test_superspeed() {
  clear
  echo "=========================================="
  echo "         三网测速脚本"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://git.io/superspeed_uxh"
  echo "此操作将从互联网下载并执行网络测速脚本。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -Lso- https://git.io/superspeed_uxh)
  set -e
  pause
}

test_ip_quality() {
  clear
  echo "=========================================="
  echo "         IP质量检测"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: IP.Check.Place"
  echo "此操作将从互联网下载并执行IP检测脚本。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -Ls IP.Check.Place)
  set -e
  pause
}

# ---------- 系统工具相关 ----------
install_rclone() {
  clear
  echo "=========================================="
  echo "         安装Rclone"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://rclone.org/install.sh"
  echo "此操作将从互联网下载并执行Rclone官方安装脚本。"
  read -rp "确定要安装Rclone吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  curl https://rclone.org/install.sh | sudo bash
  set -e
  pause
}

install_natcfg() {
  clear
  echo "=========================================="
  echo "         端口转发工具"
  echo "=========================================="
  warn "⚠️  安全警告: 即将执行远程脚本"
  echo "脚本来源: https://raw.githubusercontent.com/arloor/iptablesUtils/master/natcfg.sh"
  echo "此操作将从互联网下载并执行端口转发配置脚本。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  bash <(curl -fsSL https://us.arloor.dev/https://raw.githubusercontent.com/arloor/iptablesUtils/master/natcfg.sh)
  set -e
  pause
}

install_nfs_client() {
  clear
  echo "=========================================="
  echo "         安装NFS客户端"
  echo "=========================================="
  
  if command -v apt-get &> /dev/null; then
    echo "检测到apt包管理器，使用apt安装..."
    apt-get update && apt-get install nfs-common nfs-kernel-server -y
  elif command -v yum &> /dev/null; then
    echo "检测到yum包管理器，使用yum安装..."
    yum install nfs-utils -y
  else
    error "未检测到支持的包管理器"
    pause
    return
  fi
  
  ok "NFS客户端安装完成"
  pause
}

show_directory_usage() {
  clear
  echo "=========================================="
  echo "         查看目录占用"
  echo "=========================================="
  echo "1) 查看根目录占用（排除/mnt、/proc、/sys、/run）"
  echo "2) 查看/opt目录占用"
  read -rp "请选择: " choice
  
  case "$choice" in
    1)
      echo "正在分析根目录占用..."
      sudo du -xh --max-depth=1 --exclude=/mnt --exclude=/proc --exclude=/sys --exclude=/run / | sort -h
      ;;
    2)
      echo "正在分析/opt目录占用..."
      sudo du -h --max-depth=1 /opt | sort -h
      ;;
    *)
      error "无效选项"
      ;;
  esac
  pause
}

modify_swappiness() {
  clear
  echo "=========================================="
  echo "         修改虚拟内存使用率"
  echo "=========================================="
  echo "当前虚拟内存使用率:"
  cat /proc/sys/vm/swappiness
        echo ""
  read -rp "请输入新的使用率 (0-100，推荐1): " swappiness
  
  if [[ "$swappiness" =~ ^[0-9]+$ ]] && [ "$swappiness" -ge 0 ] && [ "$swappiness" -le 100 ]; then
    sysctl -w vm.swappiness=$swappiness
    echo "vm.swappiness=$swappiness" >> /etc/sysctl.conf
    ok "虚拟内存使用率已设置为: $swappiness"
    echo "当前值:"
    cat /proc/sys/vm/swappiness
  else
    error "无效输入，请输入0-100之间的数字"
  fi
  pause
}

install_apt_tools() {
  clear
  echo "=========================================="
  echo "         安装基础工具包（apt）"
  echo "=========================================="
  echo "正在安装: nano wget zip fuse3 tar curl sudo unzip nfs-common nfs-kernel-server libzbar0"
  
  apt-get update && apt update && apt-get install nano wget zip fuse3 tar curl sudo unzip nfs-common nfs-kernel-server libzbar0 -y
  
  ok "工具包安装完成"
  pause
}

install_yum_tools() {
  clear
  echo "=========================================="
  echo "         安装基础工具包（yum）"
  echo "=========================================="
  echo "正在安装: nano wget zip fuse3 tar unzip"
  
  yum install nano wget zip fuse3 tar unzip -y
  
  ok "工具包安装完成"
  pause
}

disable_bt_ssl() {
  clear
  echo "=========================================="
  echo "         关闭宝塔面板SSL"
  echo "=========================================="
  
  if [ ! -f /www/server/panel/data/ssl.pl ]; then
    warn "SSL配置文件不存在，可能SSL已关闭或未安装宝塔面板"
  else
    rm -f /www/server/panel/data/ssl.pl
    /etc/init.d/bt restart
    ok "宝塔面板SSL已关闭"
  fi
  pause
}

# ---------- 群辉工具相关 ----------
synology_status() {
  clear
  echo "=========================================="
  echo "         群辉查看状态"
  echo "=========================================="
  echo "查看磁盘队列深度:"
  cat /sys/block/sd*/device/queue_depth 2>/dev/null || echo "无法读取磁盘队列深度"
  echo ""
  echo "查看RAID状态:"
  cat /proc/mdstat
  pause
}

synology_disk_temp() {
  clear
  echo "=========================================="
  echo "         群辉查看硬盘温度"
  echo "=========================================="
  
  for i in {1..15}; do
    if [ -e /dev/sata$i ]; then
      echo "硬盘 sata$i 温度:"
      smartctl -a /dev/sata$i | grep -i temperature || echo "无法读取温度信息"
      echo ""
    fi
  done
  pause
}

synology_dir_permissions() {
  clear
  echo "=========================================="
  echo "         群辉查看目录权限"
  echo "=========================================="
  
  for vol in /volume1 /volume2 /volume3; do
    if [ -d "$vol" ]; then
      echo "目录 $vol 权限:"
      ls -l "$vol"
      echo ""
    fi
  done
  pause
}

synology_change_root_pwd() {
  clear
  echo "=========================================="
  echo "         群辉修改root密码"
  echo "=========================================="
  warn "此操作将修改群辉系统的root密码"
  read -sp "请输入新密码: " new_pwd
  echo ""
  read -sp "请再次确认密码: " new_pwd2
  echo ""
  
  if [ "$new_pwd" != "$new_pwd2" ]; then
    error "两次输入的密码不一致"
    pause
    return
  fi
  
  if [ -z "$new_pwd" ]; then
    error "密码不能为空"
    pause
    return
  fi
  
  synouser --setpw root "$new_pwd" 2>/dev/null && ok "root密码修改成功" || error "密码修改失败，请确认是否在群辉系统上运行"
  pause
}

synology_set_stripe_32768() {
  clear
  echo "=========================================="
  echo "         群辉改数据块（32768）"
  echo "=========================================="
  warn "此操作将修改RAID数据块大小，请谨慎操作"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  for md in md{0..8}; do
    if [ -d /sys/block/$md/md ]; then
      echo 32768 > /sys/block/$md/md/stripe_cache_size 2>/dev/null && echo "✅ $md 数据块已设置为32768" || echo "❌ $md 设置失败"
    fi
  done
  pause
}

synology_set_stripe_4096() {
  clear
  echo "=========================================="
  echo "         群辉恢复数据块（4096）"
  echo "=========================================="
  warn "此操作将恢复RAID数据块大小为默认值"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  for md in md{0..8}; do
    if [ -d /sys/block/$md/md ]; then
      echo 4096 > /sys/block/$md/md/stripe_cache_size 2>/dev/null && echo "✅ $md 数据块已恢复为4096" || echo "❌ $md 恢复失败"
    fi
  done
  pause
}

synology_super_permission() {
  clear
  echo "=========================================="
  echo "         群辉超级权限"
  echo "=========================================="
  warn "此操作将切换到root用户，请谨慎操作"
  read -rp "确定要切换到root用户吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  sudo -i
  pause
}

# ---------- PVE工具相关 ----------
install_pve_source() {
  clear
  echo "=========================================="
  echo "         PVE一键命令"
  echo "=========================================="
  warn "⚠️  安全警告: 即将下载并执行PVE源配置脚本"
  echo "脚本来源: https://bbs.x86pi.cn/file/topic/2023-11-28/file/01ac88d7d2b840cb88c15cb5e19d4305b2.gz"
  echo "此操作将从互联网下载并执行PVE配置脚本，可能会修改系统配置。"
  read -rp "确定要继续吗? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  wget -q -O /root/pve_source.tar.gz 'https://bbs.x86pi.cn/file/topic/2023-11-28/file/01ac88d7d2b840cb88c15cb5e19d4305b2.gz' && tar zxvf /root/pve_source.tar.gz && /root/./pve_source
  set -e
  pause
}

enter_pve_images() {
  clear
  echo "=========================================="
  echo "         进入PVE磁盘目录"
  echo "=========================================="
  echo "PVE磁盘目录: /var/lib/vz/images"
  
  if [ -d /var/lib/vz/images ]; then
    cd /var/lib/vz/images
    echo "✅ 已切换到 /var/lib/vz/images"
    echo "当前目录内容:"
    ls -lh
  else
    error "目录不存在，可能未安装PVE"
  fi
  pause
}

# ---------- 系统重装相关 ----------
dd_reinstall() {
  clear
  echo "=========================================="
  echo "         DD重装系统"
  echo "=========================================="
  warn "⚠️  危险操作警告"
  echo "此操作将完全格式化当前系统并重新安装！"
  echo "所有数据将被永久删除，无法恢复！"
  echo ""
  echo "脚本来源: https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
  echo "默认系统: Debian 12"
  echo "默认密码: txrui"
  echo ""
  read -rp "请输入 'YES' 确认继续: " confirm
  
  if [ "$confirm" != "YES" ]; then
    info "操作已取消"
    pause
    return
  fi
  
  read -rp "请输入系统版本 (默认: debian 12): " os_version
  os_version=${os_version:-"debian 12"}
  
  read -rp "请输入root密码 (默认: txrui): " root_pwd
  root_pwd=${root_pwd:-"txrui"}
  
  warn "最后确认：即将格式化系统并安装 $os_version，root密码: $root_pwd"
  read -rp "输入 'CONFIRM' 最终确认: " final_confirm
  
  if [ "$final_confirm" != "CONFIRM" ]; then
    info "操作已取消"
    pause
    return
  fi
  
  set +e
  curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
  bash reinstall.sh $os_version --password "$root_pwd"
  set -e
  pause
}

# ---------- 脚本入口 ----------
check_system
main_menu
