# 直播诊断室 2.0 全栈开发过程记录

## 一、项目背景

### 用户需求
- 基于扣子(Coze)开发的1.0直播诊断室BOT功能
- 升级到2.0 Web应用，前端直接接入扣子Bot作为核心AI引擎
- 新增OCR数据大屏识别（抖音/视频号/小红书/快手）
- 可部署到阿里云服务器

### 技术栈
- 前端：React 19 + TypeScript + Tailwind CSS + shadcn/ui + Framer Motion
- 后端：Hono + tRPC 11.x + Drizzle ORM + MySQL
- AI引擎：扣子Coze Bot API（对话方式）
- OCR：百度OCR（通用文字识别高精度版）
- 部署：阿里云轻量服务器（CentOS）

### 已配置的API密钥
- 扣子Coze: Bot ID 7607002201290211382 + Token（5月21日到期）
- 百度OCR: API Key + Secret Key
- 阿里云MySQL: 已配置数据库连接

---

## 二、已交付功能（前端已完成）

### 功能清单
| 页面 | 功能 | 开发状态 |
|------|------|----------|
| Landing主页 | 功能介绍 + 联系作者微信二维码 | ✅ 已开发 |
| 工作台 | KPI总览 + 快捷入口 | ✅ 已开发 |
| 话术创作 | AI 6阶段话术生成 + 保存到话术库 | ✅ 已开发 |
| 违规诊断 | 实时违禁词扫描 + 合规评分 | ✅ 已开发 |
| 数据大屏诊断 | OCR识别 + AI诊断（抖音/小红书/快手/视频号） | ✅ 已开发 |
| 话术库 | 用户隔离 + 收藏/搜索/管理 | ✅ 已开发 |
| 数据分析 | 转化率趋势 + 话术排行 | ✅ 已开发 |
| 设置中心 | API配置 + 偏好设置 | ✅ 已开发 |

---

## 三、部署过程及问题记录

### 问题1：文件传输方式选择错误

**现象**：
- 6MB的deploy.zip通过socket TCP流传输反复损坏
- 解压时报错：`bad zipfile offset`、`invalid compressed data to inflate`
- 服务器上文件不完整，导致前端显示旧版本

**根本原因**：
- TCP流式传输对大文件（6MB）不可靠，没有应用层校验
- 沙盒到阿里云服务器的网络链路易丢包

**尝试过的传输方式**：
| 方式 | 结果 | 原因 |
|------|------|------|
| socket TCP流传输 | ❌ 反复失败 | 大文件丢包，无校验 |
| GitHub仓库上传 | ❌ 服务器wget下载为0字节 | 服务器无法连接GitHub raw CDN |
| localtunnel内网穿透 | ❌ 沙盒出站被墙 | 安全策略限制 |
| 文件托管服务(transfer.sh等) | ❌ 全部失败 | 沙盒网络限制 |

**最终解决方案**：
- 改为传单个前端构建文件（每个<1MB），3个文件总计1.8MB
- 先删除旧文件再复制新文件（避免cp覆盖提示）
- 后端api/目录直接在服务器本地保留，只更新前端dist/

---

### 问题2：后端启动失败

**现象**：
- `node dist/boot.js` 报错：`Cannot find module 'command-line-args'`
- 端口3000无监听，`ss -tlnp | grep 3000` 无输出

**根本原因**：
1. `dist/boot.js` 是前端Vite构建产物，**不是后端启动入口**
2. 正确后端入口是 `api/boot.ts`（TypeScript），需要 `tsx` 运行
3. `.env` 环境变量文件丢失或为空
4. `api/lib/vite.ts` 中 `import.meta.dirname` 路径解析错误

**解决方案**：
1. 用 `npx tsx api/boot.ts` 启动后端（TypeScript直接运行）
2. 重新写入 `.env` 文件（包含所有API密钥）
3. 修复 `api/lib/vite.ts` 路径（`__dirname` 指向 `api/lib/`，需 `../../../dist/public`）

---

### 问题3：Nginx反向代理配置混乱

**现象**：
- 浏览器访问 `47.103.67.33` 返回 502 Bad Gateway
- `curl http://127.0.0.1:3000/` 正常（后端已启动）

**根本原因**：
- Nginx配置指向了3001端口（旧应用），但新应用在3000端口
- 用 `sed` 修改Nginx配置导致语法错误（`unknown directive "proxy_pass"`）
- 宝塔面板自动管理的nginx配置被手动修改搞乱

**解决方案**：
- 重写 `/www/server/panel/vhost/nginx/live-battle-room.conf`
- `proxy_pass http://127.0.0.1:3000;`
- `/etc/init.d/nginx restart`

---

### 问题4：前端文件未更新

**现象**：
- 浏览器显示的还是旧版本界面
- 话术创作没有"生成"按钮
- 数据大屏布局未紧凑化
- 话术库还是旧数据

**根本原因**：
- zip传输损坏，解压后的 `dist/public/assets/` 仍然是旧文件
- 前端构建产物文件名有hash（如 `index-DXGUWNcJ.js`），每次构建会变化
- 服务器上的文件被反复覆盖但内容未更新

**验证方法**：
```bash
# 检查前端文件是否包含新代码
grep -o '保存到话术库' dist/public/assets/index-*.js
grep 'disabled:opacity-70' dist/public/assets/index-*.js
```

---

### 问题5：生成按钮位置问题

**现象**：
- 话术创作页面左侧输入面板内容太多
- "生成话术"按钮在面板底部，被截断在屏幕外
- 左侧面板没有滚动条

**根本原因**：
- 面板高度固定 `h-[calc(100vh-80px)]`，内容超出后无滚动
- 按钮放在 `ScrollArea` 外部

**修复方案**：
- 给外层容器添加 `overflow-auto`
- 确保按钮在可视区域内

---

## 四、当前服务器状态

### 服务器信息
- IP: 47.103.67.33
- 系统: CentOS（非Ubuntu/Debian，无apt-get）
- Node.js: v22.15.0
- Nginx: 宝塔面板管理
- MySQL: 阿里云RDS（已配置连接）

### 应用启动方式
```bash
cd /opt/livestream-diagnosis
NODE_ENV=production npx tsx api/boot.ts
```

### 目录结构
```
/opt/livestream-diagnosis/
├── api/                    # 后端代码（tRPC路由、中间件）
│   ├── boot.ts            # 启动入口
│   ├── router.ts          # tRPC路由聚合
│   ├── cozeRouter.ts      # 扣子Bot代理
│   ├── ocrRouter.ts       # 百度OCR接口
│   ├── scriptRouter.ts    # 话术库CRUD
│   └── lib/
│       ├── env.ts         # 环境变量
│       └── vite.ts        # 静态文件服务
├── db/
│   └── schema.ts          # 数据库表结构
├── dist/
│   └── public/            # 前端构建产物
│       ├── index.html
│       └── assets/        # JS/CSS文件
├── contracts/             # 共享类型定义
├── .env                   # API密钥配置
└── package.json
```

### 当前进程
- tsx api/boot.ts 监听 3000 端口
- Nginx 反向代理 80 → 3000

---

## 五、待修复问题清单

### 高优先级
1. **前端文件更新**：确认dist/public/assets/是最新构建产物
2. **生成按钮可见性**：确保按钮在可视区域内
3. **数据大屏布局**：紧凑化，一屏显示全部

### 中优先级
4. **Landing主页**：添加微信二维码图片
5. **话术库保存功能**：从话术创作页保存到话术库
6. **用户数据隔离**：localStorage user_id 隔离

### 低优先级
7. **管理员后台**：用户数据查看+导出表格
8. **支付接口**：支付宝/微信支付条件咨询
9. **注销功能**：取消注销账号按钮

---

## 六、给接手人的建议

### 1. 前端文件更新的正确方式
```bash
# 不要传zip！直接传单个文件
cd /opt/livestream-diagnosis

# 删除旧的前端JS/CSS（避免cp覆盖提示）
rm -f dist/public/assets/index-*.js dist/public/assets/index-*.css dist/public/index.html

# 复制新文件（无提示）
cp index.html dist/public/
cp index-*.css dist/public/assets/
cp index-*.js dist/public/assets/

# 重启
pkill -f "tsx api/boot"
NODE_ENV=production npx tsx api/boot.ts &
```

### 2. 调试方法
```bash
# 检查后端日志
cat /tmp/app.log

# 检查端口
ss -tlnp | grep 3000

# 测试后端
curl -s http://127.0.0.1:3000/

# 检查nginx
cat /www/server/panel/vhost/nginx/live-battle-room.conf
nginx -t

# 检查前端文件是否最新
grep -o '保存到话术库' dist/public/assets/index-*.js
grep 'opacity-70' dist/public/assets/index-*.js
```

### 3. 关键文件位置
- 后端启动：`api/boot.ts`
- 环境变量：`.env`
- Nginx配置：`/www/server/panel/vhost/nginx/live-battle-room.conf`
- 前端入口：`dist/public/index.html`

---

## 七、API密钥（敏感信息）

**注意：这些密钥已配置在服务器 .env 文件中**

| 服务 | 密钥/ID |
|------|---------|
| 扣子Bot ID | 7607002201290211382 |
| 扣子Token | pat_...（5月21日到期） |
| 百度OCR API Key | GKygd5LfLQvekpjAjFg9BfVW |
| 百度OCR Secret | u0o4SQ3KGfOe5Ee27dqncj7lQko34eui |

---

## 八、总结

### 已完成
- ✅ 全栈架构搭建（前端+后端+数据库+扣子Bot+百度OCR）
- ✅ 所有8个页面开发完成
- ✅ 后端服务启动（3000端口监听）
- ✅ Nginx反向代理配置
- ✅ 扣子Bot和百度OCR API接入

### 未完成
- ❌ 前端文件未成功更新到服务器（传输问题）
- ❌ 生成按钮可见性（CSS/layout问题）
- ❌ 数据大屏紧凑布局
- ❌ Landing主页微信二维码
- ❌ 管理员后台

### 核心问题
**文件传输是最大瓶颈**：沙盒到阿里云服务器的6MB zip传输反复损坏，导致前端代码无法更新。建议改用Git部署或其他更可靠的传输方式。
