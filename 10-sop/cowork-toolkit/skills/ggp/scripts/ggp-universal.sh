#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════╗
# ║  GGP Universal — Guanghe Gate Protocol (Cowork Edition)      ║
# ║  三轮交叉审计 · 多项目支持 · JSON 报告输出                      ║
# ╚═══════════════════════════════════════════════════════════════╝
#
# 用法: ggp-universal.sh [commit_range] [repo_path]
# 默认: HEAD~1..HEAD, 当前目录
# 输出: stdout + /tmp/ggp-report.json

set -e

BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}║  $1${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
}

RANGE="${1:-HEAD~1..HEAD}"
REPO_PATH="${2:-$(pwd)}"
cd "$REPO_PATH"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$REPO_PATH")
REPO_NAME=$(basename "$REPO_ROOT")
HAS_ISSUES=0
REPORT_FILE="/tmp/ggp-report.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ===== 语言检测 =====
detect_language() {
  if [ -f "$REPO_ROOT/Package.swift" ]; then echo "swift"
  elif [ -f "$REPO_ROOT/package.json" ]; then echo "typescript"
  elif [ -f "$REPO_ROOT/setup.py" ] || [ -f "$REPO_ROOT/pyproject.toml" ]; then echo "python"
  elif [ -f "$REPO_ROOT/pubspec.yaml" ]; then echo "dart"
  elif [ -f "$REPO_ROOT/build.gradle" ] || [ -f "$REPO_ROOT/build.gradle.kts" ]; then echo "kotlin"
  else echo "generic"
  fi
}

LANG=$(detect_language)
case "$LANG" in
  swift)      EXT="*.swift" ;;
  typescript) EXT="*.ts" ;;
  python)     EXT="*.py" ;;
  dart)       EXT="*.dart" ;;
  kotlin)     EXT="*.kt" ;;
  *)          EXT="*" ;;
esac

# ===== 检查 API Keys =====
MISSING=""
[ -z "$GOOGLE_AI_KEY" ] && MISSING="$MISSING GOOGLE_AI_KEY"
[ -z "$OPENAI_API_KEY" ] && MISSING="$MISSING OPENAI_API_KEY"
if [ -n "$MISSING" ]; then
  echo -e "${RED}❌ 缺少环境变量:$MISSING${RESET}"
  cat > "$REPORT_FILE" << EJSON
{"repo":"$REPO_NAME","range":"$RANGE","timestamp":"$TIMESTAMP","rounds":[],"verdict":"ERROR","exit_code":2,"error":"Missing API keys:$MISSING"}
EJSON
  exit 2
fi

# ===== 获取 diff =====
DIFF=$(git diff "$RANGE" -- "$EXT" | head -3000)
if [ -z "$DIFF" ]; then
  echo -e "${YELLOW}没有检测到 ${LANG} 文件变更（${EXT}）${RESET}"
  cat > "$REPORT_FILE" << EJSON
{"repo":"$REPO_NAME","range":"$RANGE","timestamp":"$TIMESTAMP","rounds":[],"verdict":"SKIP","exit_code":0,"error":"No changes detected"}
EJSON
  exit 0
fi

HAS_TEST_CHANGES=$(git diff --name-only "$RANGE" -- "$EXT" | grep -ci 'test' || true)

echo -e "${BOLD}GGP Universal — Guanghe Gate Protocol${RESET}"
echo -e "项目: ${BOLD}$REPO_NAME${RESET} (${LANG})"
echo -e "审计范围: ${BOLD}$RANGE${RESET}"
echo -e "测试文件变更: ${BOLD}${HAS_TEST_CHANGES} 个文件${RESET}"
echo ""

# ===== API 调用函数 =====
call_google_ai() {
  local model="$1"
  local system_prompt="$2"
  local user_prompt="$3"
  ESCAPED_SYSTEM=$(echo "$system_prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  ESCAPED_USER=$(echo "$user_prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  curl -s "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GOOGLE_AI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"system_instruction\": {\"parts\": [{\"text\": $ESCAPED_SYSTEM}]},
      \"contents\": [{\"parts\": [{\"text\": $ESCAPED_USER}]}],
      \"generationConfig\": {\"maxOutputTokens\": 4096}
    }" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'candidates' in data and len(data['candidates']) > 0:
        parts = data['candidates'][0].get('content', {}).get('parts', [])
        for part in parts:
            if 'text' in part:
                print(part['text'])
    elif 'error' in data:
        print('API_ERROR:', json.dumps(data['error'], ensure_ascii=False))
    else:
        print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print(f'PARSE_ERROR: {e}')
"
}

call_responses_api() {
  local model="$1"
  local system_prompt="$2"
  local user_prompt="$3"
  ESCAPED_SYSTEM=$(echo "$system_prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  ESCAPED_USER=$(echo "$user_prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  curl -s "https://api.openai.com/v1/responses" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{
      \"model\": \"$model\",
      \"instructions\": $ESCAPED_SYSTEM,
      \"input\": $ESCAPED_USER,
      \"max_output_tokens\": 4096
    }" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'output' in data:
        for item in data['output']:
            if item.get('type') == 'message':
                for content in item.get('content', []):
                    if content.get('type') == 'output_text':
                        print(content['text'])
    elif 'error' in data:
        print('API_ERROR:', json.dumps(data['error'], ensure_ascii=False))
    else:
        print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print(f'PARSE_ERROR: {e}')
"
}

# ===== 审计提示词（语言自适应）=====
LANG_CONTEXT="项目语言: ${LANG}"
case "$LANG" in
  swift)
    LANG_CONTEXT="项目语言: Swift/SwiftUI。关注 Sendable 合规、@MainActor、SPM 包 public 可见性、SwiftUI View 性能、State 管理。"
    ;;
  typescript)
    LANG_CONTEXT="项目语言: TypeScript。关注类型安全、null 处理、async/await 模式、React hooks 依赖数组、ESM 导入。"
    ;;
  python)
    LANG_CONTEXT="项目语言: Python。关注类型注解、异常处理、异步模式、依赖注入、测试覆盖。"
    ;;
esac

ROUND1_SYSTEM="你是一名 ${LANG} 项目的**安全与逻辑审计员**。${LANG_CONTEXT}

专注领域：
1. 逻辑错误：边界条件、类型安全、错误处理路径
2. 安全隐患：不安全的类型转换、未处理的错误、资源泄漏
3. 架构合理性：职责划分、模块边界、public API 设计
4. 并发安全：数据竞争、死锁风险、线程安全

规则：
- 只报告实际问题，按严重程度排序（Critical > High > Medium > Low）
- 每个问题必须包含：文件路径、问题描述、建议修复方案
- 如果没有问题就说「无问题」
- 不要赞美代码，不要重复 diff 内容"

ROUND2_SYSTEM="你是一名 ${LANG} 项目的**工程质量审计员**。${LANG_CONTEXT}

专注领域：
1. 性能问题：不必要的计算、内存泄漏、主线程阻塞
2. 命名规范：是否遵循语言社区惯例
3. 代码质量：函数长度、重复代码、可读性
4. API 设计：public API 是否最小且一致
5. 可维护性：硬编码值、魔法数字、缺少文档

规则：
- 只报告实际问题，按影响程度排序
- 每个问题必须包含：文件路径、问题描述、建议修复方案
- 如果没有问题就说「无问题」
- 不要赞美代码，不要与 Round 1 重叠"

ROUND3_SYSTEM="你是一名 ${LANG} 项目的**测试完整性审计员**。${LANG_CONTEXT}

专注领域：
1. 遗漏检查：对比源码 public API，找出应测未测的接口
2. 反例构造：尝试构造测试通过但行为错误的场景
3. 断言充分性：是否存在 tautological test
4. 预期值核对：硬编码预期值是否与源码实际值匹配
5. 边界覆盖：边界值、空值、异常路径是否覆盖

规则：
- 只报告实际问题，按严重程度排序
- 每个问题必须包含：文件路径、问题描述、建议修复方案
- 如果没有问题就说「无问题」
- 不要与 Round 1/2 重叠"

USER_PROMPT="请审查以下 git diff（${REPO_NAME} — ${LANG} 项目）：

\`\`\`diff
${DIFF}
\`\`\`"

# ===== 执行三轮审计 =====
R1_JSON=""
R2_JSON=""
R3_JSON=""

banner "Round 1: 安全与逻辑审计 (Gemini 3.1 Pro)  "
RESULT1=$(call_google_ai "gemini-3.1-pro-preview" "$ROUND1_SYSTEM" "$USER_PROMPT")
echo "$RESULT1"
R1_HAS_CRITICAL=false
if echo "$RESULT1" | grep -qi "critical\|high"; then
  HAS_ISSUES=1
  R1_HAS_CRITICAL=true
fi
R1_ESCAPED=$(echo "$RESULT1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
R1_JSON="{\"round\":1,\"model\":\"gemini-3.1-pro\",\"role\":\"安全与逻辑\",\"has_critical\":${R1_HAS_CRITICAL},\"output\":${R1_ESCAPED}}"

banner "Round 2: 工程质量审计 (GPT-5.4)            "
RESULT2=$(call_responses_api "gpt-5.4" "$ROUND2_SYSTEM" "$USER_PROMPT")
echo "$RESULT2"
R2_HAS_CRITICAL=false
if echo "$RESULT2" | grep -qi "critical\|high"; then
  HAS_ISSUES=1
  R2_HAS_CRITICAL=true
fi
R2_ESCAPED=$(echo "$RESULT2" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
R2_JSON="{\"round\":2,\"model\":\"gpt-5.4\",\"role\":\"工程质量\",\"has_critical\":${R2_HAS_CRITICAL},\"output\":${R2_ESCAPED}}"

if [ "$HAS_TEST_CHANGES" -gt 0 ]; then
  TESTS_DIR=$(find "$REPO_ROOT" -type d -name "Tests" -maxdepth 3 | head -1)
  SOURCES_DIR=$(find "$REPO_ROOT" -type d -name "Sources" -maxdepth 3 | head -1)
  TEST_CONTENT=""
  SOURCE_SIGNATURES=""
  if [ -n "$TESTS_DIR" ]; then
    TEST_CONTENT=$(find "$TESTS_DIR" -name '*Tests.swift' -o -name '*.test.ts' -o -name 'test_*.py' | head -10 | xargs cat 2>/dev/null | head -2000)
  fi
  if [ -n "$SOURCES_DIR" ]; then
    SOURCE_SIGNATURES=$(grep -rn 'public\|static\|export\|LOCKED\|OPEN' "$SOURCES_DIR" --include="$EXT" 2>/dev/null | head -1000)
  fi
  ROUND3_PROMPT="请审查以下测试代码的完整性。

## 测试代码
\`\`\`
${TEST_CONTENT}
\`\`\`

## 被测源码 public API 签名
\`\`\`
${SOURCE_SIGNATURES}
\`\`\`

## 本次变更 diff
\`\`\`diff
${DIFF}
\`\`\`"

  banner "Round 3: 测试完整性审计 (Gemini 3.1 Pro)  "
  RESULT3=$(call_google_ai "gemini-3.1-pro-preview" "$ROUND3_SYSTEM" "$ROUND3_PROMPT")
  echo "$RESULT3"
  R3_HAS_CRITICAL=false
  if echo "$RESULT3" | grep -qi "critical\|high"; then
    HAS_ISSUES=1
    R3_HAS_CRITICAL=true
  fi
  R3_ESCAPED=$(echo "$RESULT3" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  R3_JSON="{\"round\":3,\"model\":\"gemini-3.1-pro\",\"role\":\"测试完整性\",\"has_critical\":${R3_HAS_CRITICAL},\"skipped\":false,\"output\":${R3_ESCAPED}}"
else
  echo -e "${YELLOW}⏭️  Round 3 跳过（本次无测试文件变更）${RESET}"
  R3_JSON="{\"round\":3,\"model\":\"gemini-3.1-pro\",\"role\":\"测试完整性\",\"has_critical\":false,\"skipped\":true,\"output\":\"跳过：无测试文件变更\"}"
fi

# ===== 最终判定 =====
if [ "$HAS_ISSUES" -eq 0 ]; then
  VERDICT="PASS"
  EXIT_CODE=0
  echo -e "\n${GREEN}${BOLD}  ✅ GGP PASS — 所有轮次通过，无 Critical/High${RESET}\n"
else
  VERDICT="FAIL"
  EXIT_CODE=1
  echo -e "\n${RED}${BOLD}  ❌ GGP FAIL — 存在 Critical/High，需修复后重审${RESET}\n"
fi

cat > "$REPORT_FILE" << EJSON
{
  "repo": "${REPO_NAME}",
  "range": "${RANGE}",
  "language": "${LANG}",
  "timestamp": "${TIMESTAMP}",
  "rounds": [${R1_JSON},${R2_JSON},${R3_JSON}],
  "verdict": "${VERDICT}",
  "exit_code": ${EXIT_CODE}
}
EJSON

echo -e "报告已写入: ${BOLD}${REPORT_FILE}${RESET}"
exit $EXIT_CODE
