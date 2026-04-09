-- Optly: updated_at triggers, aggregation helpers, AI context RPC, insight rate limit

-- -----------------------------------------------------------------------------
-- updated_at trigger
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER subscriptions_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER habits_updated_at
  BEFORE UPDATE ON public.habits
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER health_data_updated_at
  BEFORE UPDATE ON public.health_data
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER finance_snapshots_updated_at
  BEFORE UPDATE ON public.finance_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER insight_cards_updated_at
  BEFORE UPDATE ON public.insight_cards
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- -----------------------------------------------------------------------------
-- Subscription savings aggregation (per user, monthly potential)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_subscription_savings(p_user_id uuid)
RETURNS TABLE (
  cancel_or_downgrade_count bigint,
  total_potential_monthly_savings numeric,
  keep_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COUNT(*) FILTER (WHERE s.ai_recommendation IN ('cancel', 'downgrade'))::bigint,
    COALESCE(
      SUM(s.potential_savings) FILTER (WHERE s.ai_recommendation IN ('cancel', 'downgrade')),
      0
    )::numeric(14, 4),
    COUNT(*) FILTER (WHERE s.ai_recommendation = 'keep')::bigint
  FROM public.subscriptions s
  WHERE s.user_id = p_user_id;
$$;

REVOKE ALL ON FUNCTION public.calculate_subscription_savings(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_subscription_savings(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.calculate_subscription_savings(uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- Combined JSON context for AI edge functions (caller must enforce user id = JWT)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_context(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'profile', (
      SELECT to_jsonb(u) - 'created_at'::text
      FROM public.users u
      WHERE u.id = p_user_id
    ),
    'health_recent', COALESCE((
      SELECT jsonb_agg(to_jsonb(h) ORDER BY h.date DESC)
      FROM (
        SELECT id, user_id, date, steps, sleep_hours, sleep_quality,
               heart_rate_avg, hrv, active_energy, energy_score
        FROM public.health_data
        WHERE user_id = p_user_id
        ORDER BY date DESC
        LIMIT 14
      ) h
    ), '[]'::jsonb),
    'habits', COALESCE((
      SELECT jsonb_agg(to_jsonb(t) ORDER BY t.name)
      FROM (
        SELECT id, user_id, name, category, frequency, streak, completions,
               ai_adjustments, goal_target, progress
        FROM public.habits
        WHERE user_id = p_user_id
      ) t
    ), '[]'::jsonb),
    'subscriptions', COALESCE((
      SELECT jsonb_agg(to_jsonb(s) ORDER BY s.name)
      FROM public.subscriptions s
      WHERE s.user_id = p_user_id
    ), '[]'::jsonb),
    'finance_snapshots', COALESCE((
      SELECT jsonb_agg(to_jsonb(f) ORDER BY f.month DESC)
      FROM (
        SELECT id, user_id, month, income, expenses_by_category,
               subscriptions_total, savings_rate, ai_suggestions
        FROM public.finance_snapshots
        WHERE user_id = p_user_id
        ORDER BY month DESC
        LIMIT 6
      ) f
    ), '[]'::jsonb),
    'focus_sessions_recent', COALESCE((
      SELECT jsonb_agg(to_jsonb(fs) ORDER BY fs.started_at DESC)
      FROM (
        SELECT id, user_id, started_at, ended_at, mode, blocked_apps, productivity_score
        FROM public.focus_sessions
        WHERE user_id = p_user_id
        ORDER BY started_at DESC
        LIMIT 30
      ) fs
    ), '[]'::jsonb),
    'calendar_proxy', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'title', fs.mode,
          'start', fs.started_at,
          'end', fs.ended_at,
          'source', 'focus_session'
        ) ORDER BY fs.started_at DESC
      )
      FROM (
        SELECT mode, started_at, ended_at
        FROM public.focus_sessions
        WHERE user_id = p_user_id
          AND started_at::date = (timezone('UTC', now()))::date
        ORDER BY started_at ASC
        LIMIT 50
      ) fs
    ), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.get_user_context(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_context(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_user_context(uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- Per-user rate limiting for insight generation (service_role writes from edge)
-- -----------------------------------------------------------------------------
CREATE TABLE public.insight_rate_limits (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  endpoint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX insight_rate_limits_user_endpoint_created_idx
  ON public.insight_rate_limits (user_id, endpoint, created_at DESC);

ALTER TABLE public.insight_rate_limits ENABLE ROW LEVEL SECURITY;
-- RLS enabled with no policies: clients cannot access. service_role bypasses RLS for edge functions.
