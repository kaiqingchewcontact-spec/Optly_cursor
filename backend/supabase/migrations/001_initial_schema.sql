-- Optly initial schema: profiles, habits, health, finance, focus, briefings, insights

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

-- -----------------------------------------------------------------------------
-- public.users — app profile linked to auth.users
-- -----------------------------------------------------------------------------
CREATE TABLE public.users (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name text,
  avatar_url text,
  subscription_tier text NOT NULL DEFAULT 'free',
  trial_start timestamptz,
  trial_end timestamptz,
  preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- subscriptions — detected / managed recurring spend
-- -----------------------------------------------------------------------------
CREATE TABLE public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  provider text NOT NULL DEFAULT '',
  cost numeric(14, 4) NOT NULL DEFAULT 0,
  billing_cycle text NOT NULL DEFAULT 'monthly'
    CHECK (billing_cycle IN ('weekly', 'monthly', 'quarterly', 'annual')),
  category text NOT NULL DEFAULT 'other'
    CHECK (category IN (
      'productivity', 'entertainment', 'health', 'finance',
      'education', 'utilities', 'other'
    )),
  last_used timestamptz,
  usage_score integer NOT NULL DEFAULT 0 CHECK (usage_score >= 0 AND usage_score <= 100),
  ai_recommendation text NOT NULL DEFAULT 'keep'
    CHECK (ai_recommendation IN ('keep', 'cancel', 'downgrade')),
  potential_savings numeric(14, 4) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, name, provider)
);

CREATE INDEX subscriptions_user_id_idx ON public.subscriptions (user_id);

-- -----------------------------------------------------------------------------
-- habits
-- -----------------------------------------------------------------------------
CREATE TABLE public.habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  frequency text NOT NULL DEFAULT 'daily',
  streak integer NOT NULL DEFAULT 0,
  completions jsonb NOT NULL DEFAULT '[]'::jsonb,
  ai_adjustments jsonb NOT NULL DEFAULT '{}'::jsonb,
  goal_target numeric(14, 4),
  progress numeric(14, 4) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX habits_user_id_idx ON public.habits (user_id);

-- -----------------------------------------------------------------------------
-- health_data — daily aggregates from mobile / wearables
-- -----------------------------------------------------------------------------
CREATE TABLE public.health_data (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  date date NOT NULL,
  steps integer,
  sleep_hours numeric(6, 2),
  sleep_quality integer CHECK (sleep_quality IS NULL OR (sleep_quality >= 0 AND sleep_quality <= 100)),
  heart_rate_avg integer,
  hrv integer,
  active_energy numeric(14, 4),
  energy_score integer CHECK (energy_score IS NULL OR (energy_score >= 0 AND energy_score <= 100)),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

CREATE INDEX health_data_user_id_date_idx ON public.health_data (user_id, date DESC);

-- -----------------------------------------------------------------------------
-- finance_snapshots — monthly rollup for AI context
-- -----------------------------------------------------------------------------
CREATE TABLE public.finance_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  month date NOT NULL,
  income numeric(14, 4),
  expenses_by_category jsonb NOT NULL DEFAULT '{}'::jsonb,
  subscriptions_total numeric(14, 4),
  savings_rate numeric(7, 4),
  ai_suggestions jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, month)
);

CREATE INDEX finance_snapshots_user_id_month_idx ON public.finance_snapshots (user_id, month DESC);

-- -----------------------------------------------------------------------------
-- focus_sessions — productivity / “calendar-like” blocks for briefing context
-- -----------------------------------------------------------------------------
CREATE TABLE public.focus_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL,
  ended_at timestamptz NOT NULL,
  mode text NOT NULL DEFAULT 'focus',
  blocked_apps jsonb NOT NULL DEFAULT '[]'::jsonb,
  productivity_score integer CHECK (
    productivity_score IS NULL OR (productivity_score >= 0 AND productivity_score <= 100)
  ),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX focus_sessions_user_id_started_idx ON public.focus_sessions (user_id, started_at DESC);

-- -----------------------------------------------------------------------------
-- daily_briefings — cached AI daily plan (JSON matches app DailyBriefing shape)
-- -----------------------------------------------------------------------------
CREATE TABLE public.daily_briefings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  date date NOT NULL,
  content jsonb NOT NULL,
  generated_at timestamptz NOT NULL DEFAULT now(),
  cached_until timestamptz NOT NULL,
  UNIQUE (user_id, date)
);

CREATE INDEX daily_briefings_user_id_date_idx ON public.daily_briefings (user_id, date DESC);
CREATE INDEX daily_briefings_cached_until_idx ON public.daily_briefings (cached_until);

-- -----------------------------------------------------------------------------
-- insight_cards
-- -----------------------------------------------------------------------------
CREATE TABLE public.insight_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('savings', 'health', 'productivity', 'habit')),
  title text NOT NULL,
  description text NOT NULL,
  impact_score integer NOT NULL DEFAULT 0 CHECK (impact_score >= 0 AND impact_score <= 100),
  action_text text,
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  acted_on boolean NOT NULL DEFAULT false,
  associated_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX insight_cards_user_id_created_idx ON public.insight_cards (user_id, created_at DESC);
CREATE INDEX insight_cards_user_id_type_idx ON public.insight_cards (user_id, type);

-- -----------------------------------------------------------------------------
-- Auto-create public.users row when a new auth user is created
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name'),
    NEW.raw_user_meta_data ->> 'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.focus_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_briefings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insight_cards ENABLE ROW LEVEL SECURITY;

-- users: own row only
CREATE POLICY users_select_own ON public.users FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()));
CREATE POLICY users_update_own ON public.users FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid())) WITH CHECK (id = (SELECT auth.uid()));
CREATE POLICY users_insert_own ON public.users FOR INSERT TO authenticated
  WITH CHECK (id = (SELECT auth.uid()));

-- subscriptions
CREATE POLICY subscriptions_all_own ON public.subscriptions FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- habits
CREATE POLICY habits_all_own ON public.habits FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- health_data
CREATE POLICY health_data_all_own ON public.health_data FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- finance_snapshots
CREATE POLICY finance_snapshots_all_own ON public.finance_snapshots FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- focus_sessions
CREATE POLICY focus_sessions_all_own ON public.focus_sessions FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- daily_briefings
CREATE POLICY daily_briefings_all_own ON public.daily_briefings FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));

-- insight_cards
CREATE POLICY insight_cards_all_own ON public.insight_cards FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()));
