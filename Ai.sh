#!/bin/bash

# AI 服务连通性检测脚本
# 只检测 Gemini / ChatGPT 网页版 & 手机App版是否可用

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMEOUT=12

# 检测 URL，返回 HTTP 状态码
get_code() {
    curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        "$1" 2>/dev/null
}

# 判断状态码是否代表"可达"
is_ok() {
    case "$1" in
        200|301|302|307|308|400|401|403|429) return 0 ;;
        *) return 1 ;;
    esac
}

# 打印单项检测结果
check_item() {
    local label="$1"
    local url="$2"
    printf "    %-40s" "$label"
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

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      AI 服务连通性检测                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Gemini ────────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}▶ Gemini (Google)${NC}"

gemini_web=0
gemini_app=0

check_item "网页版 gemini.google.com"       "https://gemini.google.com"       && gemini_web=$((gemini_web+1))
check_item "网页版 aistudio.google.com"     "https://aistudio.google.com"     && gemini_web=$((gemini_web+1))
check_item "App版  googleapis API"          "https://generativelanguage.googleapis.com/v1beta/models?key=TEST" && gemini_app=$((gemini_app+1))
check_item "App版  accounts.google.com"     "https://accounts.google.com"     && gemini_app=$((gemini_app+1))

echo ""

# ── ChatGPT ───────────────────────────────────────────────────────────────────
echo -e "  ${YELLOW}▶ ChatGPT (OpenAI)${NC}"

gpt_web=0
gpt_app=0

check_item "网页版 chatgpt.com"             "https://chatgpt.com"             && gpt_web=$((gpt_web+1))
check_item "网页版 openai.com"              "https://openai.com"              && gpt_web=$((gpt_web+1))
check_item "App版  api.openai.com"          "https://api.openai.com/v1/models" && gpt_app=$((gpt_app+1))
check_item "App版  ios.chat.openai.com"     "https://ios.chat.openai.com"     && gpt_app=$((gpt_app+1))

echo ""

# ── 最终结论 ──────────────────────────────────────────────────────────────────
verdict() {
    local ok="$1" total="$2"
    if [ "$ok" -ge "$total" ]; then
        echo -e "${GREEN}✓ 可用${NC}"
    elif [ "$ok" -ge 1 ]; then
        echo -e "${YELLOW}⚠ 部分可用${NC}"
    else
        echo -e "${RED}✗ 不可用${NC}"
    fi
}

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              最终结论                    ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC}  %-18s  %-12s  %-12s  ${BLUE}║${NC}\n" "服务" "网页版" "手机App版"
echo -e "${BLUE}║${NC}  ──────────────────────────────────────  ${BLUE}║${NC}"
printf "${BLUE}║${NC}  %-18s  " "Gemini"
printf "%-20b  " "$(verdict $gemini_web 2)"
verdict $gemini_app 2
printf "${BLUE}║${NC}  %-18s  " "ChatGPT"
printf "%-20b  " "$(verdict $gpt_web 2)"
verdict $gpt_app 2
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ 可用${NC}     = 直连正常，无需代理"
echo -e "  ${YELLOW}⚠ 部分可用${NC} = 部分端点可达，功能可能受限"
echo -e "  ${RED}✗ 不可用${NC}   = IP 被封锁，需要代理"
echo ""
