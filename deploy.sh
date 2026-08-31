#!/bin/bash
# NT团建方案 GitHub 部署脚本
# 用法: GITHUB_TOKEN=ghp_xxx ./deploy.sh
set -e

TOKEN="$GITHUB_TOKEN"
REPO="nt-team-building-2026"
if [ -z "$TOKEN" ]; then
  echo "错误：请设置 GITHUB_TOKEN 环境变量"
  exit 1
fi

echo "==> 1/4 获取 GitHub 用户信息..."
USER=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/user | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["login"])' 2>/dev/null)
if [ -z "$USER" ]; then
  echo "错误：Token 无效，请检查后重试"
  exit 1
fi
echo "    GitHub 用户: $USER"

echo "==> 2/4 创建公开仓库 $REPO ..."
HTTP=$(curl -s -o /tmp/gh_repo.json -w "%{http_code}" -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO\",\"description\":\"NT公司2026秋季团建方案（5线对比）\",\"public\":true}")
if [ "$HTTP" = "422" ]; then
  echo "    仓库已存在，继续推送..."
elif [ "$HTTP" != "201" ]; then
  echo "错误：创建仓库失败 HTTP=$HTTP"
  cat /tmp/gh_repo.json | head -5
  exit 1
fi

echo "==> 3/4 推送代码到 main 分支..."
git remote remove origin 2>/dev/null || true
git remote add origin "https://x-access-token:${TOKEN}@github.com/${USER}/${REPO}.git"
git push -u origin main 2>&1 | tail -3
git remote set-url origin "https://github.com/${USER}/${REPO}.git"

echo "==> 4/4 开启 GitHub Pages..."
HTTP=$(curl -s -o /tmp/gh_pages.json -w "%{http_code}" -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/${USER}/${REPO}/pages \
  -d '{"source":{"branch":"main","path":"/"}}')
if [ "$HTTP" = "409" ] || [ "$HTTP" = "201" ]; then
  echo "    Pages 已开启（首次构建约需1-2分钟）"
else
  echo "    Pages 开启返回 HTTP=$HTTP（可能已开启）"
  cat /tmp/gh_pages.json | head -3
fi

echo ""
echo "=============================================="
echo " 部署完成！"
echo " 仓库地址: https://github.com/${USER}/${REPO}"
echo " 在线预览: https://${USER}.github.io/${REPO}/"
echo " 后期编辑: 修改 HTML 后执行 git push origin main 即自动更新"
echo "=============================================="
