BEGIN;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.has_any_app_role(required_roles public.app_role[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = auth.uid()
      AND role = ANY(required_roles)
      AND active
  );
$$;

DROP POLICY profiles_read_own ON public.profiles;
CREATE POLICY profiles_read_own
ON public.profiles
FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  OR private.has_any_app_role(ARRAY['supervisor', 'admin']::public.app_role[])
);

DROP POLICY user_roles_read_own ON public.user_roles;
CREATE POLICY user_roles_read_own
ON public.user_roles
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR private.has_any_app_role(ARRAY['supervisor', 'admin']::public.app_role[])
);

DROP POLICY incident_photos_insert_by_reception ON storage.objects;
CREATE POLICY incident_photos_insert_by_reception
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'incident-photos'
  AND owner_id = auth.uid()::text
  AND private.has_any_app_role(
    ARRAY['reception', 'supervisor', 'admin']::public.app_role[]
  )
);

DROP POLICY incident_photos_read_by_authorized_roles ON storage.objects;
CREATE POLICY incident_photos_read_by_authorized_roles
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'incident-photos'
  AND private.has_any_app_role(
    ARRAY['reception', 'supervisor', 'admin']::public.app_role[]
  )
);

REVOKE EXECUTE ON FUNCTION public.has_any_app_role(public.app_role[])
  FROM PUBLIC, anon, authenticated, service_role;
DROP FUNCTION public.has_any_app_role(public.app_role[]);

GRANT USAGE ON SCHEMA private TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION private.has_any_app_role(public.app_role[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_any_app_role(public.app_role[])
  TO authenticated, service_role;

COMMIT;
