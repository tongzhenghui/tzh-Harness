#!/bin/bash
# tzhOS Harness Cowork Skills — 上游同步脚本
# 拉取 superpowers 最新版，对比差异，生成评估报告供创始人裁决
#
# 用法：bash sync-upstream.sh [--apply]
#   无参数：仅评估，生成差异报告（默认）
#   --apply：确认升级后执行，覆盖原版内容 + 保留 Harness 层 + 重新打包

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_REPO="https://github.com/obra/superpowers.git"
UPSTREAM_DIR="/tmp/superpowers-upstream"
REPORT_FILE="$SCRIPT_DIR/UPSTREAM-DIFF-REPORT.md"

# Skill 名称映射：本地目录名 → superpowers 目录名
declare -A SKILL_MAP=(
  ["systematic-debugging"]="systematic-debugging"
  ["parallel-agent-dispatch"]="dispatching-parallel-agents"
  ["git-worktree-isolation"]="using-git-worktrees"
  ["code-review-reception"]="receiving-code-review"
  ["skill-writing-tdd"]="writing-skills"
)

MODE="evaluate"
if [[ "${1:-}" == "--apply" ]]; then
  MODE="apply"
fi

# ── Step 1: 拉取上游 ──

echo "📡 拉取 superpowers 最新版..."
if [ -d "$UPSTREAM_DIR" ] && [ -d "$UPSTREAM_DIR/.git" ]; then
  cd "$UPSTREAM_DIR" && git pull --ff-only 2>&1 | head -3 || echo "   ⚠️  pull 失败，使用本地缓存"
elif [ -d "$UPSTREAM_DIR" ] && [ ! -d "$UPSTREAM_DIR/.git" ] && [ -d "$UPSTREAM_DIR/skills" ]; then
  # 已有解压缓存（如 superpowers-main/ 目录）
  echo "   使用本地缓存: $UPSTREAM_DIR"
else
  # 尝试常见本地位置
  for candidate in \
    "$HOME/Workspace/01_Repos/superpowers" \
    "$HOME/superpowers" \
    "/tmp/superpowers" \
    "$(dirname "$SCRIPT_DIR")/../../superpowers"; do
    if [ -d "$candidate/skills" ]; then
      UPSTREAM_DIR="$candidate"
      echo "   使用本地仓库: $UPSTREAM_DIR"
      break
    fi
  done

  # 都没有，尝试 clone
  if [ ! -d "$UPSTREAM_DIR/skills" ]; then
    git clone --depth 1 "$UPSTREAM_REPO" "$UPSTREAM_DIR" 2>&1 | tail -1 || {
      echo "❌ 无法访问 GitHub 且无本地缓存。请先在宿主机执行："
      echo "   git clone https://github.com/obra/superpowers.git /tmp/superpowers"
      exit 1
    }
  fi
fi
UPSTREAM_COMMIT=$(cd "$UPSTREAM_DIR" && git log --oneline -1 2>/dev/null || echo "(本地缓存，无 Git 信息)")
echo "   上游版本: $UPSTREAM_COMMIT"
echo ""

# ── Step 2: 逐个 Skill 对比 ──

if [ "$MODE" = "evaluate" ]; then
  echo "📊 生成评估报告..."
  cat > "$REPORT_FILE" << HEADER
# Superpowers 上游同步评估报告

> 生成时间: $(date '+%Y-%m-%d %H:%M')
> 上游版本: $UPSTREAM_COMMIT
> 状态: **待创始人裁决**

---

HEADER

  HAS_CHANGES=false

  for local_name in "${!SKILL_MAP[@]}"; do
    upstream_name="${SKILL_MAP[$local_name]}"
    local_file="$SCRIPT_DIR/$local_name/SKILL.md"
    upstream_file="$UPSTREAM_DIR/skills/$upstream_name/SKILL.md"

    if [ ! -f "$upstream_file" ]; then
      echo "  ⚠️  $local_name: 上游文件不存在，跳过"
      continue
    fi

    # 提取本地文件中 Harness 层之前的部分（原版内容）
    # Harness 层标记：## tzhOS Harness Governance Layer
    local_base=$(sed '/^## tzhOS Harness Governance Layer/,$d' "$local_file" | sed '/^---$/,$!d' | tail -n +2 | head -n -1)
    # 直接用完整文件对比更准确：去掉 frontmatter 和 Harness 层
    local_body=$(awk '/^---$/{n++} n==1{next} /^## tzhOS Harness Governance Layer/{exit} {print}' "$local_file")
    upstream_body=$(awk '/^---$/{n++} n==1{next} {print}' "$upstream_file")

    # 对比
    DIFF_OUTPUT=$(diff <(echo "$local_body") <(echo "$upstream_body") 2>/dev/null || true)

    if [ -z "$DIFF_OUTPUT" ]; then
      echo "  ✅ $local_name: 无变化"
      echo "## $local_name → \`$upstream_name\`" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
      echo "✅ 无变化" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    else
      HAS_CHANGES=true
      LINES_CHANGED=$(echo "$DIFF_OUTPUT" | grep -c "^[<>]" || echo 0)
      echo "  🔄 $local_name: $LINES_CHANGED 行差异"

      echo "## $local_name → \`$upstream_name\`" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
      echo "🔄 **有变化**（$LINES_CHANGED 行差异）" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
      echo '```diff' >> "$REPORT_FILE"
      echo "$DIFF_OUTPUT" | head -50 >> "$REPORT_FILE"
      if [ $(echo "$DIFF_OUTPUT" | wc -l) -gt 50 ]; then
        echo "... (截断，完整差异请用 diff 命令查看)" >> "$REPORT_FILE"
      fi
      echo '```' >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    fi

    # 检查辅助文件变化
    upstream_dir_path="$UPSTREAM_DIR/skills/$upstream_name"
    local_dir_path="$SCRIPT_DIR/$local_name"
    NEW_FILES=$(diff <(cd "$local_dir_path" && find . -type f -name "*.md" -o -name "*.ts" -o -name "*.sh" | sort) \
                     <(cd "$upstream_dir_path" && find . -type f -name "*.md" -o -name "*.ts" -o -name "*.sh" | grep -v "test-" | grep -v "CREATION-LOG" | sort) \
                     2>/dev/null | grep "^>" || true)
    if [ -n "$NEW_FILES" ]; then
      echo "    📄 上游新增文件: $NEW_FILES"
      echo "📄 上游新增辅助文件:" >> "$REPORT_FILE"
      echo '```' >> "$REPORT_FILE"
      echo "$NEW_FILES" >> "$REPORT_FILE"
      echo '```' >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    fi
  done

  if [ "$HAS_CHANGES" = true ]; then
    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "## 裁决" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "- [ ] 确认升级：执行 \`bash sync-upstream.sh --apply\`" >> "$REPORT_FILE"
    echo "- [ ] 拒绝本次：无需操作，下次再评估" >> "$REPORT_FILE"
    echo "- [ ] 部分采纳：手动编辑后执行 \`bash package-all.sh\`" >> "$REPORT_FILE"
  fi

  echo ""
  echo "📄 评估报告已生成: $REPORT_FILE"
  if [ "$HAS_CHANGES" = true ]; then
    echo "⚠️  有变化，请创始人审阅后决定是否升级"
  else
    echo "✅ 所有 Skill 与上游一致，无需升级"
  fi

# ── Step 3: 应用升级（仅 --apply 模式）──

elif [ "$MODE" = "apply" ]; then
  echo "🔄 应用上游升级..."

  for local_name in "${!SKILL_MAP[@]}"; do
    upstream_name="${SKILL_MAP[$local_name]}"
    local_file="$SCRIPT_DIR/$local_name/SKILL.md"
    upstream_file="$UPSTREAM_DIR/skills/$upstream_name/SKILL.md"

    if [ ! -f "$upstream_file" ]; then
      echo "  ⚠️  $local_name: 上游文件不存在，跳过"
      continue
    fi

    # 提取本地的 Harness 治理层（从 ## tzhOS Harness Governance Layer 到文件末尾）
    HARNESS_LAYER=$(sed -n '/^---$/,$ { /^## tzhOS Harness Governance Layer/,$ p }' "$local_file")

    if [ -z "$HARNESS_LAYER" ]; then
      echo "  ⚠️  $local_name: 未找到 Harness 治理层，跳过（需手动处理）"
      continue
    fi

    # 提取本地的 YAML frontmatter（保留 Harness 自定义的 name 和 description）
    LOCAL_FRONTMATTER=$(sed -n '1,/^---$/p' "$local_file" | head -n 3)

    # 提取上游正文（去掉 frontmatter）
    UPSTREAM_BODY=$(awk '/^---$/{n++} n>=2{print}' "$upstream_file")

    # 组装：本地 frontmatter + 上游正文 + 分隔线 + Harness 层
    {
      echo "$LOCAL_FRONTMATTER"
      echo "$UPSTREAM_BODY"
      echo ""
      echo "---"
      echo ""
      echo "$HARNESS_LAYER"
    } > "$local_file"

    echo "  ✅ $local_name: 已升级（原版更新 + Harness 层保留）"

    # 同步辅助文件（覆盖，排除测试文件和创建日志）
    upstream_dir_path="$UPSTREAM_DIR/skills/$upstream_name"
    local_dir_path="$SCRIPT_DIR/$local_name"
    find "$upstream_dir_path" -maxdepth 1 -type f \
      ! -name "SKILL.md" ! -name "CREATION-LOG.md" ! -name "test-*" \
      -exec cp {} "$local_dir_path/" \;
  done

  # 重新打包
  echo ""
  echo "📦 重新打包..."
  if [ -f "$SCRIPT_DIR/package-all.sh" ]; then
    bash "$SCRIPT_DIR/package-all.sh" 2>&1 | tail -3
  else
    echo "  ⚠️  package-all.sh 不存在，请手动打包"
  fi

  # 安装
  echo ""
  echo "📥 安装到本地..."
  if [ -f "$SCRIPT_DIR/install.sh" ]; then
    bash "$SCRIPT_DIR/install.sh" 2>&1 | tail -3
  fi

  echo ""
  echo "✅ 上游同步完成。请检查后 commit + push。"

  # 清理评估报告
  [ -f "$REPORT_FILE" ] && rm "$REPORT_FILE"
fi
