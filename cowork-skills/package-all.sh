#!/bin/bash
# tzhOS Harness Cowork Skills — 重新打包脚本
# 将各 Skill 子目录重新打包为 .skill 文件到 dist/
#
# 前置条件：需要 skill-creator 的 package_skill.py
# 用法：bash package-all.sh [--skill-creator <skill-creator路径>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

# 尝试自动定位 skill-creator
SKILL_CREATOR=""
CANDIDATES=(
  "$HOME/.claude/skills/skill-creator"
  "$HOME/Workspace/01_Repos/_governance/tzh-Harness/cowork-skills/../../../.skills/skills/skill-creator"
)

while [[ $# -gt 0 ]]; do
  case $1 in
    --skill-creator)
      SKILL_CREATOR="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

if [ -z "$SKILL_CREATOR" ]; then
  for candidate in "${CANDIDATES[@]}"; do
    if [ -f "$candidate/scripts/package_skill.py" ]; then
      SKILL_CREATOR="$candidate"
      break
    fi
  done
fi

if [ -z "$SKILL_CREATOR" ] || [ ! -f "$SKILL_CREATOR/scripts/package_skill.py" ]; then
  echo "❌ 找不到 skill-creator。请指定路径："
  echo "   bash package-all.sh --skill-creator <path/to/skill-creator>"
  exit 1
fi

mkdir -p "$DIST_DIR"

echo "📦 重新打包 Harness Cowork Skills"
echo "   skill-creator: $SKILL_CREATOR"
echo ""

PACKAGED=0
for skill_dir in "$SCRIPT_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  # 跳过 dist 目录
  [ "$skill_name" = "dist" ] && continue
  # 检查是否包含 SKILL.md
  [ ! -f "$skill_dir/SKILL.md" ] && continue

  echo "   📦 $skill_name ..."
  cd "$SKILL_CREATOR"
  python -m scripts.package_skill "$skill_dir" "$DIST_DIR" 2>&1 | grep -E "^(✅|❌)" || true
  PACKAGED=$((PACKAGED + 1))
done

echo ""
echo "✅ 完成！已打包 $PACKAGED 个 Skill 到 $DIST_DIR/"
