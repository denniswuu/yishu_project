# 一数打卡系统 - 部署指南

## 项目结构

```
初中数学项目/
├── index.html          # 学生端（打卡主应用）
├── admin.html          # 管理端（教师查看数据）
├── vercel.json         # Vercel 部署配置
└── supabase/
    └── schema.sql      # 数据库初始化脚本
```

---

## 第一步：创建 Supabase 项目

1. 打开 [https://supabase.com](https://supabase.com)，点击 **Start your project**
2. 使用 GitHub 账号登录
3. 点击 **New Project**，填写：
   - **Name**: `yishu-checkin`
   - **Database Password**: 设置一个强密码（请牢记！）
   - **Region**: 选择 `Northeast Asia (Tokyo)` 或 `Southeast Asia (Singapore)` 以获得最佳访问速度
4. 等待项目创建完成（约 2 分钟）

## 第二步：初始化数据库

1. 在 Supabase 控制台左侧菜单点击 **SQL Editor**
2. 点击 **New query**
3. 将 `supabase/schema.sql` 的全部内容粘贴进去
4. 点击 **Run** 执行
5. 确认所有表创建成功（无报错）

## 第三步：创建管理员账号

1. 在 Supabase 控制台左侧菜单点击 **Authentication** > **Users**
2. 点击 **Add user** > **Create new user**
3. 填写：
   - **Email**: `admin@yishu.app`（固定格式）
   - **Password**: 设置管理员密码
   - 勾选 **Auto confirm user**
4. 点击 **Create user**
5. 创建后，点击左侧 **Table Editor** > 找到 `profiles` 表
6. 找到刚创建的管理员用户，将 `role` 字段改为 `admin`，`username` 改为 `admin`，`display_name` 改为 `老师`

## 第四步：获取 API 密钥

1. 在 Supabase 控制台左侧菜单点击 **Settings** > **API**
2. 记录以下两个值：
   - **Project URL**: 形如 `https://xxxxx.supabase.co`
   - **anon public**: 一长串密钥

## 第五步：部署到 Vercel

### 方式一：通过 GitHub（推荐）

1. 将项目推送到 GitHub 仓库
2. 打开 [https://vercel.com](https://vercel.com)，使用 GitHub 登录
3. 点击 **Add New** > **Project**
4. 选择你的 GitHub 仓库
5. 在配置页面设置 **Environment Variables**：
   - `NEXT_PUBLIC_SUPABASE_URL` = 你的 Supabase Project URL
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = 你的 Supabase anon key
6. 点击 **Deploy**，等待部署完成

### 方式二：通过 Vercel CLI

1. 安装 Vercel CLI：
   ```bash
   npm i -g vercel
   ```
2. 在项目根目录（`初中数学项目/`）执行：
   ```bash
   vercel
   ```
3. 按提示操作，设置环境变量：
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`

### 方式三：手动上传

1. 打开 [https://vercel.com/new](https://vercel.com/new)
2. 选择 **Upload** 模板
3. 上传 `index.html`、`admin.html`、`vercel.json` 三个文件
4. 部署后在 **Settings** > **Environment Variables** 中添加环境变量

## 第六步：配置环境变量注入

由于是纯静态 HTML，需要通过 Vercel 的 `_headers` 或修改 HTML 来注入环境变量。

在 Vercel 项目根目录创建 `index.html` 的注入方式：

1. 在 Vercel 项目的 **Settings** > **Environment Variables** 添加：
   - `NEXT_PUBLIC_SUPABASE_URL` = `https://xxxxx.supabase.co`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = `你的anon key`

2. Vercel 会自动将 `NEXT_PUBLIC_` 前缀的变量注入到前端。

**但纯静态 HTML 需要额外配置**，最简单的方式是：

在 `index.html` 和 `admin.html` 中直接替换占位符：
- 将 `YOUR_SUPABASE_URL` 替换为实际的 Supabase URL
- 将 `YOUR_SUPABASE_ANON_KEY` 替换为实际的 anon key

> 注意：anon key 是公开的，这是 Supabase 的设计。安全性由 RLS（Row Level Security）策略保障。

## 第七步：访问应用

部署完成后：
- **学生端**: `https://你的域名.vercel.app`
- **管理端**: `https://你的域名.vercel.app/admin`

---

## 使用说明

### 创建学生账号

1. 学生打开应用，点击"注册"
2. 填写用户名、显示名称、密码
3. 注册后自动登录，开始使用

### 管理员操作

1. 打开 `/admin` 页面
2. 使用管理员账号登录（用户名: admin）
3. 查看所有学生打卡数据
4. 在"批量管理"中可手动添加学生

### 添加学生的另一种方式

管理员也可以在 Supabase 控制台 > Authentication > Users 中手动添加用户，然后编辑 profiles 表设置角色和信息。

---

## 常见问题

**Q: 忘记 Supabase 数据库密码怎么办？**
A: 在 Supabase > Settings > Database > Reset database password

**Q: 如何修改 45 天学习计划内容？**
A: 直接编辑 `index.html` 中的 `PLAN_DATA` 数组，重新部署即可

**Q: 数据会丢失吗？**
A: 打卡数据存储在 Supabase 云数据库中，不会因前端重新部署而丢失

**Q: 如何绑定自定义域名？**
A: Vercel > Settings > Domains，添加你的域名并配置 DNS
