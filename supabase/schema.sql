-- ═══════════════════════════════════════════════════
-- 一数打卡系统 - Supabase 数据库初始化脚本
-- 在 Supabase SQL Editor 中执行此脚本
-- ═══════════════════════════════════════════════════

-- 1. 创建 profiles 表（用户扩展信息）
-- Supabase Auth 自带 auth.users 表，这里扩展用户角色和昵称
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'admin')),
    grade TEXT DEFAULT '初一',
    avatar_color TEXT DEFAULT '#0d9488',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 创建 checkins 表（打卡记录）
CREATE TABLE IF NOT EXISTS public.checkins (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    plan_day INTEGER NOT NULL,
    plan_title TEXT NOT NULL,
    plan_phase TEXT NOT NULL,
    plan_phase_num INTEGER NOT NULL,
    duration INTEGER NOT NULL DEFAULT 90,
    note TEXT,
    mood TEXT CHECK (mood IN ('good', 'normal', 'bad')),
    checked_in_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 创建 settings 表（用户设置）
CREATE TABLE IF NOT EXISTS public.settings (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    reminder BOOLEAN DEFAULT TRUE,
    reminder_time TEXT DEFAULT '20:00',
    target_minutes INTEGER DEFAULT 90,
    current_day_index INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 创建索引提高查询性能
CREATE INDEX IF NOT EXISTS idx_checkins_user_id ON public.checkins(user_id);
CREATE INDEX IF NOT EXISTS idx_checkins_checked_in_at ON public.checkins(checked_in_at);
CREATE INDEX IF NOT EXISTS idx_checkins_user_date ON public.checkins(user_id, checked_in_at);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ═══════════════════════════════════════════════════
-- 5. Row Level Security (RLS) 策略
-- ═══════════════════════════════════════════════════

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- profiles 策略
-- 所有人可以查看所有 profile（用于管理端）
CREATE POLICY "Profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

-- 用户只能更新自己的 profile
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- 新注册用户自动创建 profile（通过触发器处理）

-- checkins 策略
-- 学生只能查看自己的打卡记录
CREATE POLICY "Students can view own checkins"
    ON public.checkins FOR SELECT
    USING (auth.uid() = user_id);

-- 管理员可以查看所有人的打卡记录
CREATE POLICY "Admins can view all checkins"
    ON public.checkins FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- 所有认证用户可以查看所有打卡记录（只读，用于排行榜）
CREATE POLICY "Authenticated users can view all checkins"
    ON public.checkins FOR SELECT
    USING (auth.role() = 'authenticated');

-- 学生只能插入自己的打卡记录
CREATE POLICY "Students can insert own checkins"
    ON public.checkins FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 学生只能删除自己的打卡记录
CREATE POLICY "Students can delete own checkins"
    ON public.checkins FOR DELETE
    USING (auth.uid() = user_id);

-- settings 策略
-- 用户只能查看自己的设置
CREATE POLICY "Users can view own settings"
    ON public.settings FOR SELECT
    USING (auth.uid() = user_id);

-- 用户只能插入自己的设置
CREATE POLICY "Users can insert own settings"
    ON public.settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 用户只能更新自己的设置
CREATE POLICY "Users can update own settings"
    ON public.settings FOR UPDATE
    USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- 6. 触发器：新用户注册时自动创建 profile 和 settings
-- ═══════════════════════════════════════════════════

-- 自动创建 profile 的函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'role', 'student')
    );
    INSERT INTO public.settings (user_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 注册触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ═══════════════════════════════════════════════════
-- 7. 便捷视图：管理端统计视图
-- ═══════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.student_stats AS
SELECT
    p.id AS user_id,
    p.username,
    p.display_name,
    p.grade,
    p.created_at AS joined_at,
    COUNT(DISTINCT date_trunc('day', c.checked_in_at)) AS total_checkin_days,
    COUNT(DISTINCT c.plan_day) AS completed_lessons,
    COALESCE(SUM(c.duration), 0) AS total_minutes,
    MAX(c.checked_in_at) AS last_checkin_at
FROM public.profiles p
LEFT JOIN public.checkins c ON c.user_id = p.id
WHERE p.role = 'student'
GROUP BY p.id, p.username, p.display_name, p.grade, p.created_at;
