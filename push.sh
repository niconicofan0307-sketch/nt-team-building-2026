#!/bin/bash
# NT团建方案 → GitHub Pages 快速发布（含代理 502 自动重试）
# 用法: ./push.sh "提交说明"      （说明省略时自动生成时间戳）
set -u

SRC="NT公司2026秋季团建方案.html"
MSG="${1:-更新方案 $(date '+%Y-%m-%d %H:%M')}"
GIT_USER="niconicofan0307-sketch"
GIT_MAIL="niconicofan0307-sketch@users.noreply.github.com"
URL="https://niconicofan0307-sketch.github.io/nt-team-building-2026/"

cd "$(dirname "$0")" || exit 1

# 1. 同步 index.html 副本（Pages 入口）
if [ -f "$SRC" ]; then
  cp "$SRC" index.html
  echo "==> 已同步 index.html"
fi

# 2. 无改动则跳过提交
git add -A
if git diff --cached --quiet; then
  echo "==> 无内容改动，直接推送（或已是最新）"
else
  git -c user.name="$GIT_USER" -c user.email="$GIT_MAIL" commit -m "$MSG"
  echo "==> 已提交: $(git log --oneline -1)"
fi

# 3. 推送（HTTP/1.1 + 重试，规避代理 502）
echo "==> 推送到 GitHub ..."
for i in 1 2 3 4 5 6; do
  OUT=$(git -c http.version=HTTP/1.1 push origin main 2>&1 | tail -2)
  if echo "$OUT" | grep -qE "main -> main|up-to-date|Everything up-to-date"; then
    echo "$OUT"
    echo "==> 推送成功（第 $i 次尝试）"
    break
  fi
  echo "    第 $i 次失败，6 秒后重试..."
  sleep 6
  if [ "$i" = "6" ]; then
    echo "!! 推送失败，最后一次输出："
    echo "$OUT"
    echo "!! 可稍后手动执行: git -c http.version=HTTP/1.1 push origin main"
    exit 1
  fi
done

# 4. 校验线上是否已更新
echo "==> 校验线上版本 ..."
sleep 3
curl -s --max-time 30 "$URL" -o /tmp/nt_online_check.html
if [ -s /tmp/nt_online_check.html ]; then
  if diff -q "$SRC" /tmp/nt_online_check.html >/dev/null 2>&1; then
    echo "==> 线上内容与本地一致 ✔"
  else
    echo "==> 线上已抓取，但与本地有差异（Pages 构建可能需 1-2 分钟，请稍后刷新）"
  fi
  echo "    在线预览: $URL"
else
  echo "!! 线上抓取失败，请手动打开确认: $URL"
fi
