const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cron = require('node-cron');
const moment = require('moment');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'yishu-checkin-secret-key-2026';

// 中间件
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 数据库连接
const db = new sqlite3.Database(path.join(__dirname, 'data', 'app.db'), (err) => {
  if (err) {
    console.error('数据库连接失败:', err);
  } else {
    console.log('数据库连接成功');
    initDatabase();
  }
});

// 初始化数据库
function initDatabase() {
  const fs = require('fs');
  const schemaPath = path.join(__dirname, '..', 'database', 'schema.sql');
  
  if (!fs.existsSync(path.join(__dirname, 'data'))) {
    fs.mkdirSync(path.join(__dirname, 'data'), { recursive: true });
  }
  
  const schema = fs.readFileSync(schemaPath, 'utf8');
  
  db.exec(schema, (err) => {
    if (err) {
      console.error('数据库初始化失败:', err);
    } else {
      console.log('数据库初始化成功');
    }
  });
}

// JWT验证中间件
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: '未提供token' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'token无效' });
    }
    req.user = user;
    next();
  });
};

// ═══════════════════════════════════════
// 用户相关API
// ═══════════════════════════════════════

// 微信登录/注册
app.post('/api/auth/wechat', async (req, res) => {
  const { openid, unionid, nickname, avatar_url } = req.body;
  
  if (!openid) {
    return res.status(400).json({ error: 'openid不能为空' });
  }
  
  try {
    // 查找用户
    db.get('SELECT * FROM users WHERE openid = ?', [openid], (err, user) => {
      if (err) {
        return res.status(500).json({ error: '数据库错误' });
      }
      
      if (user) {
        // 更新用户信息
        db.run(
          'UPDATE users SET nickname = ?, avatar_url = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
          [nickname || user.nickname, avatar_url || user.avatar_url, user.id],
          (err) => {
            if (err) console.error('更新用户信息失败:', err);
          }
        );
        
        const token = jwt.sign({ userId: user.id, openid }, JWT_SECRET, { expiresIn: '30d' });
        return res.json({ token, user: { ...user, nickname: nickname || user.nickname, avatar_url: avatar_url || user.avatar_url } });
      } else {
        // 创建新用户
        db.run(
          'INSERT INTO users (openid, unionid, nickname, avatar_url) VALUES (?, ?, ?, ?)',
          [openid, unionid, nickname, avatar_url],
          function(err) {
            if (err) {
              return res.status(500).json({ error: '创建用户失败' });
            }
            
            const userId = this.lastID;
            const token = jwt.sign({ userId, openid }, JWT_SECRET, { expiresIn: '30d' });
            
            // 为用户创建学习计划
            createUserPlan(userId);
            
            res.json({
              token,
              user: {
                id: userId,
                openid,
                nickname,
                avatar_url,
                grade: '初一',
                target_days: 45,
                daily_minutes: 90,
                reminder_time: '20:00',
                reminder_enabled: 1
              }
            });
          }
        );
      }
    });
  } catch (error) {
    res.status(500).json({ error: '服务器错误' });
  }
});

// 为用户创建学习计划
function createUserPlan(userId) {
  db.all('SELECT id FROM plan_templates ORDER BY sort_order', [], (err, templates) => {
    if (err || !templates) return;
    
    const startDate = moment().format('YYYY-MM-DD');
    
    templates.forEach((template, index) => {
      const scheduledDate = moment(startDate).add(index, 'days').format('YYYY-MM-DD');
      db.run(
        'INSERT INTO user_plans (user_id, template_id, scheduled_date) VALUES (?, ?, ?)',
        [userId, template.id, scheduledDate]
      );
    });
  });
}

// 获取用户信息
app.get('/api/user/profile', authenticateToken, (req, res) => {
  db.get('SELECT * FROM users WHERE id = ?', [req.user.userId], (err, user) => {
    if (err || !user) {
      return res.status(404).json({ error: '用户不存在' });
    }
    res.json(user);
  });
});

// 更新用户设置
app.put('/api/user/settings', authenticateToken, (req, res) => {
  const { grade, target_days, daily_minutes, reminder_time, reminder_enabled } = req.body;
  
  db.run(
    'UPDATE users SET grade = ?, target_days = ?, daily_minutes = ?, reminder_time = ?, reminder_enabled = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    [grade, target_days, daily_minutes, reminder_time, reminder_enabled, req.user.userId],
    (err) => {
      if (err) {
        return res.status(500).json({ error: '更新失败' });
      }
      res.json({ message: '更新成功' });
    }
  );
});

// ═══════════════════════════════════════
// 学习计划API
// ═══════════════════════════════════════

// 获取用户学习计划列表
app.get('/api/plans', authenticateToken, (req, res) => {
  const { status, date } = req.query;
  let sql = `
    SELECT up.*, pt.phase, pt.day_number, pt.title, pt.description, 
           pt.video_title, pt.video_url, pt.knowledge_points, pt.phase_name
    FROM user_plans up
    JOIN plan_templates pt ON up.template_id = pt.id
    WHERE up.user_id = ?
  `;
  const params = [req.user.userId];
  
  if (status) {
    sql += ' AND up.status = ?';
    params.push(status);
  }
  if (date) {
    sql += ' AND up.scheduled_date = ?';
    params.push(date);
  }
  
  sql += ' ORDER BY pt.sort_order';
  
  db.all(sql, params, (err, plans) => {
    if (err) {
      return res.status(500).json({ error: '查询失败' });
    }
    res.json(plans);
  });
});

// 获取今日计划
app.get('/api/plans/today', authenticateToken, (req, res) => {
  const today = moment().format('YYYY-MM-DD');
  
  db.get(`
    SELECT up.*, pt.phase, pt.day_number, pt.title, pt.description,
           pt.video_title, pt.video_url, pt.knowledge_points, pt.phase_name
    FROM user_plans up
    JOIN plan_templates pt ON up.template_id = pt.id
    WHERE up.user_id = ? AND up.scheduled_date = ?
  `, [req.user.userId, today], (err, plan) => {
    if (err) {
      return res.status(500).json({ error: '查询失败' });
    }
    res.json(plan || null);
  });
});

// 获取计划详情
app.get('/api/plans/:id', authenticateToken, (req, res) => {
  db.get(`
    SELECT up.*, pt.phase, pt.day_number, pt.title, pt.description,
           pt.video_title, pt.video_url, pt.knowledge_points, pt.phase_name
    FROM user_plans up
    JOIN plan_templates pt ON up.template_id = pt.id
    WHERE up.id = ? AND up.user_id = ?
  `, [req.params.id, req.user.userId], (err, plan) => {
    if (err || !plan) {
      return res.status(404).json({ error: '计划不存在' });
    }
    res.json(plan);
  });
});

// ═══════════════════════════════════════
// 打卡API
// ═══════════════════════════════════════

// 打卡
app.post('/api/checkin', authenticateToken, (req, res) => {
  const { user_plan_id, duration_minutes, note, photo_urls, mood } = req.body;
  
  if (!user_plan_id) {
    return res.status(400).json({ error: 'user_plan_id不能为空' });
  }
  
  const today = moment().format('YYYY-MM-DD');
  const now = moment().format('HH:mm:ss');
  
  db.serialize(() => {
    // 创建打卡记录
    db.run(
      'INSERT INTO checkins (user_id, user_plan_id, checkin_date, checkin_time, duration_minutes, note, photo_urls, mood) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user.userId, user_plan_id, today, now, duration_minutes || 0, note, JSON.stringify(photo_urls || []), mood],
      function(err) {
        if (err) {
          return res.status(500).json({ error: '打卡失败' });
        }
        
        // 更新用户计划状态
        db.run(
          'UPDATE user_plans SET status = "completed", completed_at = CURRENT_TIMESTAMP, duration_minutes = ?, note = ?, photo_urls = ? WHERE id = ? AND user_id = ?',
          [duration_minutes || 0, note, JSON.stringify(photo_urls || []), user_plan_id, req.user.userId],
          (err) => {
            if (err) {
              return res.status(500).json({ error: '更新计划状态失败' });
            }
            
            // 更新排行榜
            updateLeaderboard(req.user.userId);
            
            res.json({
              message: '打卡成功',
              checkin_id: this.lastID,
              streak_days: getStreakDays(req.user.userId)
            });
          }
        );
      }
    );
  });
});

// 获取打卡记录
app.get('/api/checkins', authenticateToken, (req, res) => {
  const { start_date, end_date } = req.query;
  
  let sql = `
    SELECT c.*, pt.title as plan_title, pt.day_number
    FROM checkins c
    JOIN user_plans up ON c.user_plan_id = up.id
    JOIN plan_templates pt ON up.template_id = pt.id
    WHERE c.user_id = ?
  `;
  const params = [req.user.userId];
  
  if (start_date) {
    sql += ' AND c.checkin_date >= ?';
    params.push(start_date);
  }
  if (end_date) {
    sql += ' AND c.checkin_date <= ?';
    params.push(end_date);
  }
  
  sql += ' ORDER BY c.checkin_date DESC, c.checkin_time DESC';
  
  db.all(sql, params, (err, checkins) => {
    if (err) {
      return res.status(500).json({ error: '查询失败' });
    }
    res.json(checkins);
  });
});

// 获取连续打卡天数
function getStreakDays(userId) {
  return new Promise((resolve) => {
    db.all(
      'SELECT DISTINCT checkin_date FROM checkins WHERE user_id = ? ORDER BY checkin_date DESC',
      [userId],
      (err, rows) => {
        if (err || !rows.length) {
          resolve(0);
          return;
        }
        
        let streak = 0;
        let currentDate = moment();
        
        for (const row of rows) {
          const checkinDate = moment(row.checkin_date);
          if (checkinDate.isSame(currentDate, 'day')) {
            streak++;
            currentDate.subtract(1, 'day');
          } else if (checkinDate.isSame(currentDate.clone().subtract(1, 'day'), 'day')) {
            streak++;
            currentDate.subtract(1, 'day');
          } else {
            break;
          }
        }
        
        resolve(streak);
      }
    );
  });
}

// ═══════════════════════════════════════
// 统计API
// ═══════════════════════════════════════

// 获取学习统计
app.get('/api/stats', authenticateToken, (req, res) => {
  const userId = req.user.userId;
  
  db.serialize(() => {
    const stats = {};
    
    // 总打卡天数
    db.get(
      'SELECT COUNT(DISTINCT checkin_date) as total_days FROM checkins WHERE user_id = ?',
      [userId],
      (err, row) => {
        stats.total_days = row ? row.total_days : 0;
        
        // 总学习时长
        db.get(
          'SELECT SUM(duration_minutes) as total_minutes FROM checkins WHERE user_id = ?',
          [userId],
          (err, row) => {
            stats.total_minutes = row ? row.total_minutes : 0;
            
            // 已完成计划数
            db.get(
              'SELECT COUNT(*) as completed_plans FROM user_plans WHERE user_id = ? AND status = "completed"',
              [userId],
              (err, row) => {
                stats.completed_plans = row ? row.completed_plans : 0;
                
                // 连续打卡天数
                getStreakDays(userId).then(streak => {
                  stats.streak_days = streak;
                  res.json(stats);
                });
              }
            );
          }
        );
      }
    );
  });
});

// ═══════════════════════════════════════
// 学习小组API
// ═══════════════════════════════════════

// 创建小组
app.post('/api/groups', authenticateToken, (req, res) => {
  const { name, description, max_members } = req.body;
  
  if (!name) {
    return res.status(400).json({ error: '小组名称不能为空' });
  }
  
  const inviteCode = Math.random().toString(36).substring(2, 10).toUpperCase();
  
  db.run(
    'INSERT INTO groups (name, description, max_members, invite_code, created_by) VALUES (?, ?, ?, ?, ?)',
    [name, description, max_members || 50, inviteCode, req.user.userId],
    function(err) {
      if (err) {
        return res.status(500).json({ error: '创建小组失败' });
      }
      
      const groupId = this.lastID;
      
      // 创建者加入小组
      db.run(
        'INSERT INTO group_members (group_id, user_id, role) VALUES (?, ?, "admin")',
        [groupId, req.user.userId],
        (err) => {
          if (err) {
            return res.status(500).json({ error: '加入小组失败' });
          }
          
          res.json({
            message: '小组创建成功',
            group: {
              id: groupId,
              name,
              description,
              invite_code: inviteCode
            }
          });
        }
      );
    }
  );
});

// 加入小组
app.post('/api/groups/join', authenticateToken, (req, res) => {
  const { invite_code } = req.body;
  
  if (!invite_code) {
    return res.status(400).json({ error: '邀请码不能为空' });
  }
  
  db.get('SELECT * FROM groups WHERE invite_code = ?', [invite_code.toUpperCase()], (err, group) => {
    if (err || !group) {
      return res.status(404).json({ error: '小组不存在' });
    }
    
    // 检查是否已在小组中
    db.get('SELECT * FROM group_members WHERE group_id = ? AND user_id = ?', [group.id, req.user.userId], (err, member) => {
      if (member) {
        return res.status(400).json({ error: '已在小组中' });
      }
      
      // 检查小组人数
      db.get('SELECT COUNT(*) as count FROM group_members WHERE group_id = ?', [group.id], (err, row) => {
        if (row.count >= group.max_members) {
          return res.status(400).json({ error: '小组已满' });
        }
        
        db.run(
          'INSERT INTO group_members (group_id, user_id) VALUES (?, ?)',
          [group.id, req.user.userId],
          (err) => {
            if (err) {
              return res.status(500).json({ error: '加入小组失败' });
            }
            res.json({ message: '加入成功', group });
          }
        );
      });
    });
  });
});

// 获取小组排行榜
app.get('/api/groups/:id/leaderboard', authenticateToken, (req, res) => {
  const today = moment().format('YYYY-MM-DD');
  
  db.all(`
    SELECT u.id, u.nickname, u.avatar_url,
           COUNT(DISTINCT c.checkin_date) as total_days,
           SUM(c.duration_minutes) as total_minutes
    FROM group_members gm
    JOIN users u ON gm.user_id = u.id
    LEFT JOIN checkins c ON u.id = c.user_id
    WHERE gm.group_id = ?
    GROUP BY u.id
    ORDER BY total_days DESC, total_minutes DESC
  `, [req.params.id], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: '查询失败' });
    }
    res.json(rows);
  });
});

// ═══════════════════════════════════════
// 排行榜更新
// ═══════════════════════════════════════

function updateLeaderboard(userId) {
  const today = moment().format('YYYY-MM-DD');
  
  db.get(
    'SELECT COUNT(DISTINCT checkin_date) as completed_days, SUM(duration_minutes) as total_duration FROM checkins WHERE user_id = ?',
    [userId],
    (err, stats) => {
      if (err) return;
      
      getStreakDays(userId).then(streak => {
        db.run(
          'INSERT OR REPLACE INTO leaderboard (user_id, record_date, completed_days, total_duration, streak_days) VALUES (?, ?, ?, ?, ?)',
          [userId, today, stats.completed_days, stats.total_duration, streak]
        );
      });
    }
  );
}

// ═══════════════════════════════════════
// 提醒任务（定时任务）
// ═══════════════════════════════════════

// 每日提醒任务
function sendDailyReminders() {
  const now = moment().format('HH:mm');
  
  db.all(
    'SELECT * FROM users WHERE reminder_enabled = 1 AND reminder_time = ?',
    [now],
    (err, users) => {
      if (err || !users) return;
      
      users.forEach(user => {
        // 检查今日是否已打卡
        const today = moment().format('YYYY-MM-DD');
        db.get(
          'SELECT * FROM checkins WHERE user_id = ? AND checkin_date = ?',
          [user.id, today],
          (err, checkin) => {
            if (!checkin) {
              // 发送提醒（这里需要接入微信服务号API）
              console.log(`发送提醒给用户 ${user.nickname || user.id}: 该学习了！`);
              
              // 记录提醒
              db.run(
                'INSERT INTO reminders (user_id, reminder_type, scheduled_at, content) VALUES (?, ?, ?, ?)',
                [user.id, 'daily', moment().format('YYYY-MM-DD HH:mm:ss'), '今日学习提醒']
              );
            }
          }
        );
      });
    }
  );
}

// 每分钟检查一次提醒
cron.schedule('* * * * *', sendDailyReminders);

// ═══════════════════════════════════════
// 健康检查
// ═══════════════════════════════════════

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: moment().format() });
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`服务器运行在端口 ${PORT}`);
  console.log(`API文档: http://localhost:${PORT}/api/health`);
});

// 优雅关闭
process.on('SIGINT', () => {
  db.close((err) => {
    if (err) {
      console.error('关闭数据库失败:', err);
    } else {
      console.log('数据库连接已关闭');
    }
    process.exit(0);
  });
});
