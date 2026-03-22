#!/bin/bash
# tzhOS Harness Cowork Skills — 一键安装脚本
# 将 dist/ 中的所有 .skill 包安装到用户 Skill 目录
#
# 用法：bash install.sh [--target <目标目录>]
# 默认目标：~/.claude/skills/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

# 解析参数
TARGET_DIR="${HOME}/.claude/skills"
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: bash install.sh [--target <目标目录>]"
      exit 1
      ;;
  esac
done

# 检查 dist 目录
if [ ! -d "$DIST_DIR" ]; then
  echo "❌ 找不到 dist/ 目录: $DIST_DIR"
  exit 1
fi

SKILL_FILES=("$DIST_DIR"/*.skill)
if [ ${#SKILL_FILES[@]} -eq 0 ]; then
  echo "❌ dist/ 目录中没有 .skill 文件"
  exit 1
fi

# 创建目标目录
mkdir -p "$TARGET_DIR"

echo "📦 tzhOS Harness Cowork Skills 安装"
echo "   来源: $DIST_DIR"
echo "   目标: $TARGET_DIR"
echo ""

INSTALLED=0
for skill_file in "${SKILL_FILES[@]}"; do
  skill_name=$(basename "$skill_file" .skill)

  # 解压 .skill (ZIP 格式) 到目标目录
  if [ -d "$TARGET_DIR/$skill_name" ]; then
    echo "   ♻️  更新: $skill_name"
    rm -rf "$TARGET_DIR/$skill_name"
  else
    echo "   ✅ 安装: $skill_name"
  fi

  unzip -qo "$skill_file" -d "$TARGET_DIR"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "✅ 完成！已安装 $INSTALLED 个 Skill 到 $TARGET_DIR"
echo ""
echo "验证方式："
echo "  1. 打开 Cowork，新建对话"
echo "  2. 输入: \"帮我调试这个 Bug\"（应触发 systematic-debugging）"
echo "  3. 输入: \"并行处理这些任务\"（应触发 parallel-agent-dispatch）"
