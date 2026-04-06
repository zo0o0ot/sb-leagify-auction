-- PostgREST pre_request hook
-- Reads x-session-token header and sets app.session_token for RLS policies.

CREATE OR REPLACE FUNCTION public.pre_request()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token text;
BEGIN
  BEGIN
    v_token := current_setting('request.headers', true)::json->>'x-session-token';
  EXCEPTION WHEN others THEN
    v_token := null;
  END;

  PERFORM set_config('app.session_token', COALESCE(v_token, ''), true);
END;
$$;

-- Register the pre_request function with PostgREST
ALTER ROLE authenticator SET pgrst.db_pre_request TO 'public.pre_request';

-- Notify PostgREST to reload config
NOTIFY pgrst, 'reload config';
