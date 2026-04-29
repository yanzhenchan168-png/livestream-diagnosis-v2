#!/bin/bash
# 直播诊断室2.0 安装脚本 - 适配宝塔环境
set -e

APP_DIR="/opt/livestream-diagnosis"

echo "=========================================="
echo "  直播诊断室 2.0 - 一键安装"
echo "=========================================="

# 检查 Node.js
echo ""
echo "📦 检查 Node.js..."
if ! command -v node &> /dev/null; then
    echo "   安装 Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi
echo "   ✅ Node.js $(node -v)"

# 安装 PM2
if ! command -v pm2 &> /dev/null; then
    echo "📦 安装 PM2..."
    npm install -g pm2
fi

# 创建目录
mkdir -p $APP_DIR
cd $APP_DIR

# 解压项目
echo ""
echo "📂 解压项目..."
if [ ! -f "/tmp/deploy.zip" ]; then
    echo "❌ 未找到 /tmp/deploy.zip"
    echo "请确认文件已上传到 /tmp/deploy.zip"
    exit 1
fi
unzip -o /tmp/deploy.zip -d $APP_DIR

# 安装依赖
echo ""
echo "📦 安装依赖..."
npm install --production

# 同步数据库
echo ""
echo "🗄️ 同步数据库..."
npm run db:push

# 构建并启动
echo ""
echo "🚀 构建并启动..."
npm run build 2>/dev/null || true
pm2 start ecosystem.config.cjs || pm2 start dist/boot.js --name "livestream-diagnosis"
pm2 save

# 防火墙
ufw allow 3000/tcp 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ✅ 安装完成！"
echo "=========================================="
echo "访问: http://$(curl -s ip.sb 2>/dev/null):3000"
echo "管理: pm2 status"
