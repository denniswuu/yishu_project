-- 一数初中数学打卡App 数据库设计
-- 使用 SQLite 作为开发数据库，生产可迁移到 PostgreSQL/MySQL

-- 用户表
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    openid VARCHAR(64) UNIQUE NOT NULL,           -- 微信openid
    unionid VARCHAR(64),                           -- 微信unionid
    nickname VARCHAR(64),                          -- 昵称
    avatar_url TEXT,                               -- 头像URL
    phone VARCHAR(20),                             -- 手机号
    grade VARCHAR(20) DEFAULT '初一',              -- 年级
    target_days INTEGER DEFAULT 45,                -- 计划天数
    daily_minutes INTEGER DEFAULT 90,              -- 每日学习时长(分钟)
    reminder_time TIME DEFAULT '20:00',            -- 提醒时间
    reminder_enabled BOOLEAN DEFAULT 1,            -- 是否开启提醒
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 学习计划表（45天计划模板）
CREATE TABLE plan_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phase INTEGER NOT NULL,                        -- 第几阶段(1-5)
    day_number INTEGER NOT NULL,                   -- 第几天(1-45)
    title VARCHAR(128) NOT NULL,                   -- 标题
    description TEXT,                              -- 描述
    video_title VARCHAR(256),                      -- 视频标题
    video_url TEXT,                                -- 视频链接
    knowledge_points TEXT,                         -- 知识点(JSON数组)
    estimated_minutes INTEGER DEFAULT 90,          -- 预计学习时长
    phase_name VARCHAR(64),                        -- 阶段名称
    sort_order INTEGER NOT NULL                    -- 排序
);

-- 用户学习计划实例
CREATE TABLE user_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    template_id INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',          -- pending/completed/skipped
    scheduled_date DATE,                           -- 计划日期
    completed_at DATETIME,                         -- 完成时间
    duration_minutes INTEGER DEFAULT 0,            -- 实际学习时长
    note TEXT,                                     -- 学习笔记
    photo_urls TEXT,                               -- 拍照记录(JSON数组)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (template_id) REFERENCES plan_templates(id)
);

-- 打卡记录表
CREATE TABLE checkins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    user_plan_id INTEGER NOT NULL,
    checkin_date DATE NOT NULL,
    checkin_time TIME NOT NULL,
    duration_minutes INTEGER DEFAULT 0,
    note TEXT,
    photo_urls TEXT,
    mood VARCHAR(20),                              -- 心情: good/normal/bad
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (user_plan_id) REFERENCES user_plans(id)
);

-- 学习小组表
CREATE TABLE groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(64) NOT NULL,
    description TEXT,
    max_members INTEGER DEFAULT 50,
    invite_code VARCHAR(16) UNIQUE,                -- 邀请码
    created_by INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- 小组成员表
CREATE TABLE group_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role VARCHAR(20) DEFAULT 'member',             -- admin/member
    joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(group_id, user_id)
);

-- 排行榜记录表（每日快照）
CREATE TABLE leaderboard (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER,
    user_id INTEGER NOT NULL,
    record_date DATE NOT NULL,
    completed_days INTEGER DEFAULT 0,              -- 已完成天数
    total_duration INTEGER DEFAULT 0,              -- 总学习时长(分钟)
    streak_days INTEGER DEFAULT 0,                 -- 连续打卡天数
    rank INTEGER,                                  -- 排名
    FOREIGN KEY (group_id) REFERENCES groups(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 提醒记录表
CREATE TABLE reminders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    reminder_type VARCHAR(32) NOT NULL,            -- daily/weekly/milestone
    scheduled_at DATETIME NOT NULL,
    sent_at DATETIME,                              -- 实际发送时间
    status VARCHAR(20) DEFAULT 'pending',          -- pending/sent/failed
    content TEXT,                                  -- 提醒内容
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 系统配置表
CREATE TABLE configs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key VARCHAR(64) UNIQUE NOT NULL,
    config_value TEXT,
    description TEXT
);

-- 插入45天计划模板数据
INSERT INTO plan_templates (phase, day_number, title, description, video_title, video_url, knowledge_points, estimated_minutes, phase_name, sort_order) VALUES
-- 第一阶段: 基础速成 (Day 1-10)
(1, 1, '数与式的基本概念', '正数、负数、有理数、无理数、数轴、相反数、绝对值', '通法合集第2集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["有理数", "数轴", "绝对值"]', 90, '基础速成', 1),
(1, 2, '整式运算与乘法公式', '单项式、多项式、合并同类项、平方差公式、完全平方公式', '通法合集第3集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["整式", "乘法公式"]', 90, '基础速成', 2),
(1, 3, '因式分解（基础方法）', '提公因式法、公式法', '通法合集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["因式分解", "提公因式"]', 90, '基础速成', 3),
(1, 4, '因式分解（进阶技巧）', '十字相乘法、分组分解法', '重难点合集', 'https://space.bilibili.com/14229967', '["十字相乘", "分组分解"]', 90, '基础速成', 4),
(1, 5, '分式与二次根式', '分式的概念与运算、二次根式的化简', '通法合集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["分式", "二次根式"]', 90, '基础速成', 5),
(1, 6, '分式与二次根式练习', '巩固练习与错题整理', '自行练习', '', '["练习", "错题"]', 90, '基础速成', 6),
(1, 7, '一元一次方程与二元一次方程组', '解法步骤、代入消元法、加减消元法', '通法合集第10-11集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["一元一次方程", "二元一次方程组"]', 90, '基础速成', 7),
(1, 8, '一元二次方程（解法）', '直接开平方法、配方法、公式法、因式分解法', '通法合集第12集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["一元二次方程", "求根公式"]', 90, '基础速成', 8),
(1, 9, '韦达定理与含参方程', '根与系数关系、参数讨论', '通法合集第13集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["韦达定理", "含参方程"]', 90, '基础速成', 9),
(1, 10, '阶段复习一：数与式、方程', '整理错题、知识点梳理、自我检测', '复习', '', '["复习", "错题整理"]', 90, '基础速成', 10),

-- 第二阶段: 方程不等式与基础函数 (Day 11-20)
(2, 11, '不等式与不等式组', '不等式性质、解集表示、一元一次不等式组', '通法合集第10集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["不等式", "不等式组"]', 90, '函数基础', 11),
(2, 12, '含参不等式与实际应用', '参数讨论、应用题', '通法合集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["含参不等式", "应用题"]', 90, '函数基础', 12),
(2, 13, '一次函数基础', 'y=kx+b、图像与性质、待定系数法', '通法合集第14集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["一次函数", "图像"]', 90, '函数基础', 13),
(2, 14, '一次函数应用与反比例函数', '实际应用、反比例函数图像与性质', '通法合集第14集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["反比例函数", "应用"]', 90, '函数基础', 14),
(2, 15, '函数图像与性质综合', '巩固练习、图像分析', '自行练习', '', '["练习", "图像分析"]', 90, '函数基础', 15),
(2, 16, '二次函数基础（图像与性质）', 'y=ax²+bx+c、开口方向、顶点坐标、对称轴', '通法合集第16集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["二次函数", "顶点"]', 90, '函数基础', 16),
(2, 17, '二次函数与方程、不等式', '二次函数与一元二次方程关系', '通法合集第16-17集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["二次函数", "方程"]', 90, '函数基础', 17),
(2, 18, '二次函数三种表达式转化', '一般式、顶点式、交点式', '自行练习', '', '["表达式", "转化"]', 90, '函数基础', 18),
(2, 19, '二次函数应用题', '最大利润、最大面积等实际问题', '通法合集第15集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["应用题", "最值"]', 90, '函数基础', 19),
(2, 20, '阶段复习二：函数基础', '整理错题、知识点梳理', '复习', '', '["复习", "错题"]', 90, '函数基础', 20),

-- 第三阶段: 几何基础 (Day 21-30)
(3, 21, '三角形全等判定与性质', 'SSS、SAS、ASA、AAS、HL', '通法合集第18集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["全等三角形", "判定"]', 90, '几何基础', 21),
(3, 22, '相似三角形判定与性质', 'AA、SAS、SSS、射影定理', '通法合集第18集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["相似三角形", "射影定理"]', 90, '几何基础', 22),
(3, 23, '相似三角形深入', '相似比、面积比、综合应用', '重难点合集第6集', 'https://space.bilibili.com/14229967', '["相似比", "面积比"]', 90, '几何基础', 23),
(3, 24, '四边形性质与判定', '平行四边形、矩形、菱形、正方形', '自行补充', '', '["四边形", "判定"]', 90, '几何基础', 24),
(3, 25, '圆的基础知识', '垂径定理、圆心角、圆周角', '通法合集第22-23集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["圆", "垂径定理"]', 90, '几何基础', 25),
(3, 26, '圆的性质', '圆周角定理、圆内接四边形', '通法合集第24-25集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["圆周角", "圆内接四边形"]', 90, '几何基础', 26),
(3, 27, '圆中线段计算', '圆幂定理、切线性质', '通法合集第26-28集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["圆幂定理", "切线"]', 90, '几何基础', 27),
(3, 28, '几何变换', '平移、旋转、对称', '重难点合集第3集', 'https://space.bilibili.com/14229967', '["平移", "旋转", "对称"]', 90, '几何基础', 28),
(3, 29, '折叠问题与动态几何', '折叠性质、动点问题初步', '重难点合集第8集', 'https://space.bilibili.com/14229967', '["折叠", "动点"]', 90, '几何基础', 29),
(3, 30, '阶段复习三：几何基础', '整理错题、模型总结', '复习', '', '["复习", "模型"]', 90, '几何基础', 30),

-- 第四阶段: 几何模型与压轴技巧 (Day 31-40)
(4, 31, '辅助线构造技巧', '倍长中线、截长补短', '通法合集第19集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["辅助线", "倍长中线"]', 90, '压轴技巧', 31),
(4, 32, '手拉手模型', '共顶点旋转、全等/相似', '重难点合集第7集', 'https://space.bilibili.com/14229967', '["手拉手", "旋转"]', 90, '压轴技巧', 32),
(4, 33, '一线三垂直与半角模型', '垂直关系、角度转化', '重难点合集第5集', 'https://space.bilibili.com/14229967', '["一线三垂直", "半角"]', 90, '压轴技巧', 33),
(4, 34, '将军饮马模型', '最短路径、对称转化', '重难点合集第16集', 'https://space.bilibili.com/14229967', '["将军饮马", "最短路径"]', 90, '压轴技巧', 34),
(4, 35, '胡不归问题与阿氏圆', '最值问题进阶', '重难点合集第17-18集', 'https://space.bilibili.com/14229967', '["胡不归", "阿氏圆"]', 90, '压轴技巧', 35),
(4, 36, '隐圆问题', '定弦定角、四点共圆', '重难点合集第3集', 'https://space.bilibili.com/14229967', '["隐圆", "定弦定角"]', 90, '压轴技巧', 36),
(4, 37, '四点共圆与托勒密定理', '判定方法、托勒密定理应用', '重难点合集第10集', 'https://space.bilibili.com/14229967', '["四点共圆", "托勒密"]', 90, '压轴技巧', 37),
(4, 38, '瓜豆原理', '主从联动、轨迹问题', '重难点合集第19集', 'https://space.bilibili.com/14229967', '["瓜豆原理", "轨迹"]', 90, '压轴技巧', 38),
(4, 39, '建系法解几何题', '坐标系、解析几何思想', '重难点合集第15集', 'https://space.bilibili.com/14229967', '["建系法", "坐标"]', 90, '压轴技巧', 39),
(4, 40, '阶段复习四：几何模型', '模型总结、综合练习', '复习', '', '["复习", "综合"]', 90, '压轴技巧', 40),

-- 第五阶段: 函数压轴与实战演练 (Day 41-45)
(5, 41, '动点与特殊图形存在性', '等腰三角形、平行四边形存在性', '通法合集第32集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["动点", "存在性"]', 90, '实战演练', 41),
(5, 42, '二次函数与特殊三角形（上）', '等腰、直角三角形', '通法合集第33集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["二次函数", "特殊三角形"]', 90, '实战演练', 42),
(5, 43, '二次函数与特殊三角形（下）', '相似三角形、综合应用', '通法合集第34集', 'https://www.bilibili.com/video/BV1qE411H7Uv', '["二次函数", "相似"]', 90, '实战演练', 43),
(5, 44, '实战中考试卷', '跟做中考真题、模拟考试', '实战中考试卷系列', 'https://space.bilibili.com/14229967', '["真题", "模拟"]', 90, '实战演练', 44),
(5, 45, '总复习与知识框架梳理', '全面回顾、制定后续计划', '复习', '', '["总复习", "框架"]', 90, '实战演练', 45);

-- 创建索引
CREATE INDEX idx_users_openid ON users(openid);
CREATE INDEX idx_user_plans_user_id ON user_plans(user_id);
CREATE INDEX idx_user_plans_date ON user_plans(scheduled_date);
CREATE INDEX idx_checkins_user_id ON checkins(user_id);
CREATE INDEX idx_checkins_date ON checkins(checkin_date);
CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_leaderboard_date ON leaderboard(record_date);
