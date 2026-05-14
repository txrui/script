#!/bin/bash

# AI 服务连通性检测脚本 v3
# 检测 Gemini / ChatGPT 网页版 & 手机App版，并显示解锁地区

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMEOUT=12

# 获取 HTTP 状态码
get_code() {
    curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "$1" 2>/dev/null
}

# 获取 HTTP 状态码 + 响应体（用于解析地区）
get_body() {
    curl -s --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "$1" 2>/dev/null
}

# 判断状态码是否可达
is_ok() {
    case "$1" in
        200|301|302|307|308|400|401|403|429) return 0 ;;
        *) return 1 ;;
    esac
}

# 打印单项检测
check_item() {
    local label="$1"
    local url="$2"
    printf "    %-42s" "$label"
    local code
    code=$(get_code "$url")
    if is_ok "$code"; then
        echo -e "${GREEN}✓ 可达 [HTTP $code]${NC}"
        return 0
    else
        echo -e "${RED}✗ 不可达 [HTTP $code]${NC}"
        return 1
    fi
}

# 结论标签
verdict() {
    local ok="$1" total="$2"
    if [ "$ok" -ge "$total" ]; then
        printf "${GREEN}✓ 可用${NC}"
    elif [ "$ok" -ge 1 ]; then
        printf "${YELLOW}⚠ 部分可用${NC}"
    else
        printf "${RED}✗ 不可用${NC}"
    fi
}

# ── 检测 Gemini 解锁地区 ──────────────────────────────────────────────────────
# Gemini 在部分地区不可用（如中国大陆），通过响应内容判断
detect_gemini_region() {
    local body code
    code=$(get_code "https://gemini.google.com")

    if ! is_ok "$code"; then
        echo "无法访问"
        return
    fi

    # 通过 Gemini API 的 countryCode 字段判断
    body=$(curl -s --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "https://gemini.google.com/app" 2>/dev/null)

    # 检查是否被重定向到不支持页面
    local redir
    redir=$(curl -s -o /dev/null -w "%{url_effective}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "Mozilla/5.0" \
        "https://gemini.google.com" 2>/dev/null)

    if echo "$redir" | grep -qi "unsupported\|unavailable\|sorry"; then
        echo "不支持该地区"
        return
    fi

    # 通过 ipinfo 获取当前 IP 所在国家，判断 Gemini 是否支持
    local country
    country=$(curl -s --max-time 5 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]')

    # Gemini 不支持的国家列表（主要封锁地区）
    local blocked="CN HK MO RU BY KP IR SY CU"
    if echo "$blocked" | grep -qw "$country"; then
        echo "该地区不支持 ($country)"
    elif [ -n "$country" ]; then
        echo "支持 ($country)"
    else
        echo "未知地区"
    fi
}

# ── 检测 ChatGPT 解锁地区 ─────────────────────────────────────────────────────
detect_gpt_region() {
    local code
    code=$(get_code "https://chatgpt.com")

    if ! is_ok "$code"; then
        echo "无法访问"
        return
    fi

    # 获取 ChatGPT 的地区检测接口
    local body
    body=$(curl -s --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "https://chatgpt.com/cdn-cgi/trace" 2>/dev/null)

    local country
    country=$(echo "$body" | grep "^loc=" | cut -d= -f2 | tr -d '[:space:]')

    if [ -z "$country" ]; then
        # 备用：通过 ipinfo 获取
        country=$(curl -s --max-time 5 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]')
    fi

    # OpenAI 不支持的国家
    local blocked="CN HK RU BY KP IR SY CU VE"
    if echo "$blocked" | grep -qw "$country"; then
        echo "该地区不支持 ($country)"
    elif [ -n "$country" ]; then
        # 进一步检测是否真正解锁（访问 /api/auth/session 看是否被拦截）
        local auth_code
        auth_code=$(get_code "https://chatgpt.com/api/auth/session")
        case "$auth_code" in
            200|401) echo "支持 ($country)" ;;
            403)     echo "IP 被封锁 ($country)" ;;
            *)       echo "支持 ($country)" ;;
        esac
    else
        echo "未知地区"
    fi
}

# ── 检测 Gemini API 可用地区 ──────────────────────────────────────────────────
detect_gemini_api_region() {
    local code
    code=$(get_code "https://generativelanguage.googleapis.com/v1beta/models?key=TEST")
    case "$code" in
        400) echo "API 可达（key无效属正常）" ;;
        403) echo "API 可达（需有效key）" ;;
        200) echo "API 可达" ;;
        429) echo "API 可达（请求限速）" ;;
        *)   echo "API 不可达 [HTTP $code]" ;;
    esac
}

# ── 检测 OpenAI API 可用地区 ──────────────────────────────────────────────────
detect_gpt_api_region() {
    local code
    code=$(get_code "https://api.openai.com/v1/models")
    case "$code" in
        401) echo "API 可达（需有效key）" ;;
        200) echo "API 可达" ;;
        403) echo "API 被封锁" ;;
        429) echo "API 可达（请求限速）" ;;
        000) echo "API 不可达（超时）" ;;
        *)   echo "API 不可达 [HTTP $code]" ;;
    esac
}

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        AI 服务连通性检测 v3                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Gemini ────────────────────────────────────────────────────────────────────
echo -e "  ${CYAN}▶ Gemini (Google)${NC}"
gemini_web=0
gemini_app=0

check_item "网页版  gemini.google.com"          "https://gemini.google.com"       && gemini_web=$((gemini_web+1))
check_item "网页版  aistudio.google.com"        "https://aistudio.google.com"     && gemini_web=$((gemini_web+1))
check_item "App版   googleapis API"             "https://generativelanguage.googleapis.com/v1beta/models?key=TEST" && gemini_app=$((gemini_app+1))
check_item "App版   accounts.google.com"        "https://accounts.google.com"     && gemini_app=$((gemini_app+1))

echo ""
printf "    %-42s" "网页版地区解锁状态"
gemini_region=$(detect_gemini_region)
if echo "$gemini_region" | grep -q "支持"; then
    echo -e "${GREEN}${gemini_region}${NC}"
elif echo "$gemini_region" | grep -q "不支持\|封锁"; then
    echo -e "${RED}${gemini_region}${NC}"
else
    echo -e "${YELLOW}${gemini_region}${NC}"
fi

printf "    %-42s" "API 端解锁状态"
gemini_api_region=$(detect_gemini_api_region)
if echo "$gemini_api_region" | grep -q "可达"; then
    echo -e "${GREEN}${gemini_api_region}${NC}"
else
    echo -e "${RED}${gemini_api_region}${NC}"
fi
echo ""

# ── ChatGPT ───────────────────────────────────────────────────────────────────
echo -e "  ${CYAN}▶ ChatGPT (OpenAI)${NC}"
gpt_web=0
gpt_app=0

check_item "网页版  chatgpt.com"                "https://chatgpt.com"             && gpt_web=$((gpt_web+1))
check_item "网页版  openai.com"                 "https://openai.com"              && gpt_web=$((gpt_web+1))
check_item "App版   api.openai.com"             "https://api.openai.com/v1/models" && gpt_app=$((gpt_app+1))
check_item "App版   ios.chat.openai.com"        "https://ios.chat.openai.com"     && gpt_app=$((gpt_app+1))

echo ""
printf "    %-42s" "网页版地区解锁状态"
gpt_region=$(detect_gpt_region)
if echo "$gpt_region" | grep -q "支持"; then
    echo -e "${GREEN}${gpt_region}${NC}"
elif echo "$gpt_region" | grep -q "不支持\|封锁"; then
    echo -e "${RED}${gpt_region}${NC}"
else
    echo -e "${YELLOW}${gpt_region}${NC}"
fi

printf "    %-42s" "API 端解锁状态"
gpt_api_region=$(detect_gpt_api_region)
if echo "$gpt_api_region" | grep -q "可达"; then
    echo -e "${GREEN}${gpt_api_region}${NC}"
else
    echo -e "${RED}${gpt_api_region}${NC}"
fi
echo ""

# ── 最终结论 ──────────────────────────────────────────────────────────────────
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                最终结论                      ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}                                              ${BLUE}║${NC}"

printf "${BLUE}║${NC}  Gemini  网页版  %-30b${BLUE}║${NC}\n" "$(verdict $gemini_web 2)"
printf "${BLUE}║${NC}  Gemini  App版   %-30b${BLUE}║${NC}\n" "$(verdict $gemini_app 2)"
printf "${BLUE}║${NC}  Gemini  地区    %-30s${BLUE}║${NC}\n" "$gemini_region"
echo -e "${BLUE}║${NC}                                              ${BLUE}║${NC}"
printf "${BLUE}║${NC}  ChatGPT 网页版  %-30b${BLUE}║${NC}\n" "$(verdict $gpt_web 2)"
printf "${BLUE}║${NC}  ChatGPT App版   %-30b${BLUE}║${NC}\n" "$(verdict $gpt_app 2)"
printf "${BLUE}║${NC}  ChatGPT 地区    %-30s${BLUE}║${NC}\n" "$gpt_region"
echo -e "${BLUE}║${NC}                                              ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ 可用${NC}     = 直连正常，无需代理"
echo -e "  ${YELLOW}⚠ 部分可用${NC} = 部分端点可达，功能可能受限"
echo -e "  ${RED}✗ 不可用${NC}   = IP 被封锁，需要代理"
echo ""
