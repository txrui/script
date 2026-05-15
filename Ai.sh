#!/bin/bash

# AI 服务连通性检测脚本 v5
# 检测 Gemini / ChatGPT / Reddit 网页版 & 手机App版

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMEOUT=12
UA_PC="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36"
UA_IOS="Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"

# ── 基础工具 ──────────────────────────────────────────────────────────────────

# 获取 HTTP 状态码
get_code() {
    local ua="${3:-$UA_PC}"
    curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "$ua" "${@:4}" \
        "$1" 2>/dev/null
}

# 获取响应体
get_body() {
    local ua="${2:-$UA_PC}"
    curl -s --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "$ua" \
        "$1" 2>/dev/null
}

# 获取不跟随跳转的状态码+跳转目标
get_redirect() {
    curl -s -o /dev/null -w "%{http_code} %{redirect_url}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "$UA_PC" \
        "$1" 2>/dev/null
}

# 判断状态码是否"服务器有响应"
is_reachable() {
    case "$1" in
        000|5??) return 1 ;;
        *) return 0 ;;
    esac
}

# 通用可访问判断（200/30x/401/403/429）
is_accessible() {
    case "$1" in
        200|301|302|307|308|401|403|429) return 0 ;;
        *) return 1 ;;
    esac
}

# 打印单项检测（带 UA 标识）
# mode: general=通用判断  strict=200/30x才算通过  body=检测响应体
check_item() {
    local label="$1"
    local url="$2"
    local ua="${3:-PC}"
    local mode="${4:-general}"   # general | strict | body_block
    local curl_ua
    [ "$ua" = "iOS" ] && curl_ua="$UA_IOS" || curl_ua="$UA_PC"

    printf "    %-44s" "$label"

    if [ "$mode" = "body_block" ]; then
        # 获取响应体，检查是否包含封锁关键词
        local body http_code
        body=$(curl -s -w "\n__HTTP_CODE__%{http_code}" \
            --max-time "$TIMEOUT" --connect-timeout 6 -L \
            -A "$curl_ua" "$url" 2>/dev/null)
        http_code=$(echo "$body" | grep "__HTTP_CODE__" | sed 's/.*__HTTP_CODE__//')
        body=$(echo "$body" | grep -v "__HTTP_CODE__")

        if [ "$http_code" = "000" ]; then
            echo -e "${RED}✗ 不可达 [超时/拒绝]${NC}"
            return 1
        fi
        # 检查响应体是否含封锁/安全拦截关键词
        if echo "$body" | grep -qiE "blocked by network|security check|access denied|you've been blocked|cloudflare|please verify|captcha|robot"; then
            echo -e "${RED}✗ 被安全拦截 [HTTP $http_code]${NC}"
            return 1
        fi
        if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
            echo -e "${GREEN}✓ 可达 [HTTP $http_code]${NC}"
            return 0
        else
            echo -e "${RED}✗ 拒绝访问 [HTTP $http_code]${NC}"
            return 1
        fi
    fi

    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "$curl_ua" "$url" 2>/dev/null)

    if [ "$mode" = "strict" ]; then
        case "$code" in
            200|301|302|307|308)
                echo -e "${GREEN}✓ 可达 [HTTP $code]${NC}"; return 0 ;;
            000)
                echo -e "${RED}✗ 不可达 [超时/拒绝]${NC}"; return 1 ;;
            *)
                echo -e "${RED}✗ 拒绝 [HTTP $code]${NC}"; return 1 ;;
        esac
    else
        # general 模式
        if is_accessible "$code"; then
            echo -e "${GREEN}✓ 可达 [HTTP $code]${NC}"
            return 0
        elif is_reachable "$code"; then
            echo -e "${YELLOW}~ 异常 [HTTP $code]${NC}"
            return 1
        else
            echo -e "${RED}✗ 不可达 [超时/拒绝]${NC}"
            return 1
        fi
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

# ── 获取当前 IP 所在国家 ──────────────────────────────────────────────────────
get_country() {
    local c
    # 优先用 cloudflare trace（最快最准）
    c=$(curl -s --max-time 5 "https://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null \
        | grep "^loc=" | cut -d= -f2 | tr -d '[:space:]')
    [ -z "$c" ] && c=$(curl -s --max-time 5 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]')
    echo "$c"
}

COUNTRY=$(get_country)

# ── Gemini 检测 ───────────────────────────────────────────────────────────────

# 检测 Gemini 是否真正解锁（不只是网络可达）
detect_gemini_unlock() {
    # 方法1：检测 Gemini 主页是否跳转到"不支持"页面
    local redir
    redir=$(curl -s -o /dev/null -w "%{url_effective}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "$UA_PC" "https://gemini.google.com" 2>/dev/null)

    if echo "$redir" | grep -qiE "unsupported|unavailable|sorry|blocked"; then
        echo "不支持该地区 ($COUNTRY)"
        return
    fi

    # 方法2：检测 Gemini API 是否返回正常错误（400=key无效=可用，403=地区封锁）
    local api_code
    api_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "$UA_PC" \
        "https://generativelanguage.googleapis.com/v1beta/models?key=INVALID_TEST_KEY_12345" 2>/dev/null)

    # 方法3：检测 Gemini App 专用端点
    local app_code
    app_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "$UA_IOS" \
        "https://gemini.google.com/app" 2>/dev/null)

    # 综合判断
    local blocked_countries="CN HK MO RU BY KP IR SY CU"
    if echo "$blocked_countries" | grep -qw "$COUNTRY"; then
        echo "该地区不支持 ($COUNTRY)"
    elif [ "$api_code" = "400" ] || [ "$api_code" = "200" ]; then
        echo "已解锁 ($COUNTRY)"
    elif [ "$api_code" = "403" ]; then
        echo "API 地区受限 ($COUNTRY)"
    else
        echo "可访问 ($COUNTRY)"
    fi
}

# 检测 ChatGPT 是否真正解锁
detect_gpt_unlock() {
    # 方法1：读取 Cloudflare trace 获取真实国家
    local cf_country
    cf_country=$(curl -s --max-time 8 "https://chatgpt.com/cdn-cgi/trace" 2>/dev/null \
        | grep "^loc=" | cut -d= -f2 | tr -d '[:space:]')
    [ -z "$cf_country" ] && cf_country="$COUNTRY"

    # 方法2：检测 OpenAI 地区检测接口
    local geo_body geo_status
    geo_body=$(curl -s --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "$UA_PC" \
        -H "Accept: application/json" \
        "https://chatgpt.com/api/auth/session" 2>/dev/null)
    geo_status=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "$UA_PC" \
        "https://chatgpt.com/api/auth/session" 2>/dev/null)

    # 方法3：检测 OpenAI 专用地区接口
    local region_body
    region_body=$(curl -s --max-time 8 \
        -A "$UA_PC" \
        "https://openai.com/api/auth/session" 2>/dev/null)

    # 方法4：检测 api.openai.com 是否返回 401（可达）还是 000（封锁）
    local api_code
    api_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "$UA_PC" \
        "https://api.openai.com/v1/models" 2>/dev/null)

    # 综合判断
    local blocked_countries="CN HK RU BY KP IR SY CU VE"
    if echo "$blocked_countries" | grep -qw "$cf_country"; then
        echo "该地区不支持 ($cf_country)"
    elif [ "$api_code" = "401" ] || [ "$api_code" = "200" ]; then
        # API 可达，说明 IP 未被封锁
        echo "已解锁 ($cf_country)"
    elif [ "$api_code" = "000" ]; then
        echo "API 被封锁 ($cf_country)"
    elif [ "$geo_status" = "200" ] || [ "$geo_status" = "401" ]; then
        echo "已解锁 ($cf_country)"
    else
        echo "可访问 ($cf_country)"
    fi
}

# 检测 Reddit 是否解锁（通过响应体判断是否被安全系统拦截）
detect_reddit_unlock() {
    # 方法1：获取主页响应体，检查是否被安全拦截
    local main_body main_code
    main_body=$(curl -s -w "\n__CODE__%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 -L \
        -A "$UA_PC" "https://www.reddit.com" 2>/dev/null)
    main_code=$(echo "$main_body" | grep "__CODE__" | sed 's/.*__CODE__//')
    main_body=$(echo "$main_body" | grep -v "__CODE__")

    local is_blocked=0
    if echo "$main_body" | grep -qiE "blocked by network|security check|you've been blocked|please verify you are a human"; then
        is_blocked=1
    fi

    # 方法2：Reddit JSON API（真正可用时返回 200 + JSON 数据）
    local api_body api_code
    api_body=$(curl -s -w "\n__CODE__%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "Reddit/Version 2023.50.0 by test" \
        -H "Accept: application/json" \
        "https://www.reddit.com/r/popular.json?limit=1" 2>/dev/null)
    api_code=$(echo "$api_body" | grep "__CODE__" | sed 's/.*__CODE__//')
    api_body=$(echo "$api_body" | grep -v "__CODE__")

    local api_has_data=0
    if echo "$api_body" | grep -q '"kind"'; then
        api_has_data=1
    fi

    # 方法3：oauth.reddit.com（App 专用，403=IP被封，200=可用）
    local oauth_code
    oauth_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" --connect-timeout 6 \
        -A "Reddit/Version 2023.50.0 by test" \
        "https://oauth.reddit.com" 2>/dev/null)

    # 综合判断
    if [ "$main_code" = "000" ]; then
        echo "无法访问 ($COUNTRY)"
    elif [ "$is_blocked" = "1" ]; then
        echo "IP 被安全系统拦截 ($COUNTRY)"
    elif [ "$api_has_data" = "1" ]; then
        echo "已解锁 ($COUNTRY)"
    elif [ "$api_code" = "200" ]; then
        echo "已解锁 ($COUNTRY)"
    elif [ "$main_code" = "200" ]; then
        echo "可访问但内容受限 ($COUNTRY)"
    else
        echo "IP 被拦截 [HTTP $main_code] ($COUNTRY)"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         AI 服务连通性检测 v5                     ║${NC}"
echo -e "${BLUE}║   Gemini / ChatGPT / Reddit  多方式验证          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  当前 IP 所在地区: ${CYAN}${COUNTRY:-未知}${NC}"
echo ""

# ── Gemini ────────────────────────────────────────────────────────────────────
echo -e "  ${CYAN}▶ Gemini (Google)${NC}"
gemini_web=0
gemini_app=0

echo -e "  ${YELLOW}  网页版 (PC)${NC}"
check_item "  gemini.google.com"                "https://gemini.google.com"           "PC"  && gemini_web=$((gemini_web+1))
check_item "  aistudio.google.com"              "https://aistudio.google.com"         "PC"  && gemini_web=$((gemini_web+1))
check_item "  gemini.google.com/app"            "https://gemini.google.com/app"       "PC"  && gemini_web=$((gemini_web+1))

echo -e "  ${YELLOW}  手机 App 版 (iOS UA)${NC}"
check_item "  gemini.google.com (iOS)"          "https://gemini.google.com"           "iOS" && gemini_app=$((gemini_app+1))
check_item "  googleapis API (App后端)"         "https://generativelanguage.googleapis.com/v1beta/models?key=TEST" "PC" && gemini_app=$((gemini_app+1))
check_item "  accounts.google.com (登录)"       "https://accounts.google.com"         "iOS" && gemini_app=$((gemini_app+1))

echo ""
printf "  %-46s" "  解锁状态检测"
gemini_unlock=$(detect_gemini_unlock)
if echo "$gemini_unlock" | grep -qE "已解锁|可访问"; then
    echo -e "${GREEN}${gemini_unlock}${NC}"
elif echo "$gemini_unlock" | grep -qE "不支持|封锁|受限"; then
    echo -e "${RED}${gemini_unlock}${NC}"
else
    echo -e "${YELLOW}${gemini_unlock}${NC}"
fi
echo ""

# ── ChatGPT ───────────────────────────────────────────────────────────────────
echo -e "  ${CYAN}▶ ChatGPT (OpenAI)${NC}"
gpt_web=0
gpt_app=0

echo -e "  ${YELLOW}  网页版 (PC)${NC}"
check_item "  chatgpt.com"                      "https://chatgpt.com"                 "PC"  && gpt_web=$((gpt_web+1))
check_item "  openai.com"                       "https://openai.com"                  "PC"  && gpt_web=$((gpt_web+1))
check_item "  auth.openai.com (登录)"           "https://auth.openai.com"             "PC"  && gpt_web=$((gpt_web+1))

echo -e "  ${YELLOW}  手机 App 版 (iOS UA)${NC}"
check_item "  chatgpt.com (iOS)"                "https://chatgpt.com"                 "iOS" && gpt_app=$((gpt_app+1))
check_item "  api.openai.com (App后端)"         "https://api.openai.com/v1/models"    "PC"  && gpt_app=$((gpt_app+1))
check_item "  ios.chat.openai.com"              "https://ios.chat.openai.com"         "iOS" && gpt_app=$((gpt_app+1))

echo ""
printf "  %-46s" "  解锁状态检测"
gpt_unlock=$(detect_gpt_unlock)
if echo "$gpt_unlock" | grep -qE "已解锁|可访问"; then
    echo -e "${GREEN}${gpt_unlock}${NC}"
elif echo "$gpt_unlock" | grep -qE "不支持|封锁"; then
    echo -e "${RED}${gpt_unlock}${NC}"
else
    echo -e "${YELLOW}${gpt_unlock}${NC}"
fi
echo ""

# ── Reddit ────────────────────────────────────────────────────────────────────
echo -e "  ${CYAN}▶ Reddit${NC}"
reddit_web=0
reddit_app=0

echo -e "  ${YELLOW}  网页版 (PC)${NC}"
check_item "  www.reddit.com"                   "https://www.reddit.com"              "PC"  "body_block" && reddit_web=$((reddit_web+1))
check_item "  reddit.com/r/popular"             "https://www.reddit.com/r/popular"    "PC"  "body_block" && reddit_web=$((reddit_web+1))
check_item "  reddit.com API (.json)"           "https://www.reddit.com/r/popular.json?limit=1" "PC" "body_block" && reddit_web=$((reddit_web+1))

echo -e "  ${YELLOW}  手机 App 版 (iOS UA)${NC}"
check_item "  www.reddit.com (iOS)"             "https://www.reddit.com"              "iOS" "body_block" && reddit_app=$((reddit_app+1))
check_item "  oauth.reddit.com (App认证)"       "https://oauth.reddit.com"            "iOS" "general"    && reddit_app=$((reddit_app+1))
check_item "  i.redd.it (图片CDN)"              "https://i.redd.it"                   "iOS" "general"    && reddit_app=$((reddit_app+1))

echo ""
printf "  %-46s" "  解锁状态检测"
reddit_unlock=$(detect_reddit_unlock)
if echo "$reddit_unlock" | grep -qE "已解锁|可访问"; then
    echo -e "${GREEN}${reddit_unlock}${NC}"
elif echo "$reddit_unlock" | grep -qE "不支持|封锁"; then
    echo -e "${RED}${reddit_unlock}${NC}"
else
    echo -e "${YELLOW}${reddit_unlock}${NC}"
fi
echo ""

# ── 最终结论 ──────────────────────────────────────────────────────────────────
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  最终结论                        ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC}                                                  ${BLUE}║${NC}"

# Gemini
printf "${BLUE}║${NC}  Gemini  网页版    "
verdict $gemini_web 3
printf "   (${gemini_web}/3 通过)\n"
printf "${BLUE}║${NC}  Gemini  App版     "
verdict $gemini_app 3
printf "   (${gemini_app}/3 通过)\n"
printf "${BLUE}║${NC}  Gemini  解锁地区  ${CYAN}%-30s${NC}${BLUE}║${NC}\n" "$gemini_unlock"

echo -e "${BLUE}║${NC}                                                  ${BLUE}║${NC}"

# ChatGPT
printf "${BLUE}║${NC}  ChatGPT 网页版    "
verdict $gpt_web 3
printf "   (${gpt_web}/3 通过)\n"
printf "${BLUE}║${NC}  ChatGPT App版     "
verdict $gpt_app 3
printf "   (${gpt_app}/3 通过)\n"
printf "${BLUE}║${NC}  ChatGPT 解锁地区  ${CYAN}%-30s${NC}${BLUE}║${NC}\n" "$gpt_unlock"

echo -e "${BLUE}║${NC}                                                  ${BLUE}║${NC}"

# Reddit
printf "${BLUE}║${NC}  Reddit  网页版    "
verdict $reddit_web 3
printf "   (${reddit_web}/3 通过)\n"
printf "${BLUE}║${NC}  Reddit  App版     "
verdict $reddit_app 3
printf "   (${reddit_app}/3 通过)\n"
printf "${BLUE}║${NC}  Reddit  解锁地区  ${CYAN}%-30s${NC}${BLUE}║${NC}\n" "$reddit_unlock"

echo -e "${BLUE}║${NC}                                                  ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ 可用${NC}     = 直连正常，无需代理"
echo -e "  ${YELLOW}⚠ 部分可用${NC} = 部分端点可达，功能可能受限"
echo -e "  ${RED}✗ 不可用${NC}   = IP 被封锁，需要代理"
echo ""
