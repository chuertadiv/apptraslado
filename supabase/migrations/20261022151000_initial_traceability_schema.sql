BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TYPE public.app_role AS ENUM (
  'packing',
  'origin',
  'inventory',
  'logistics',
  'dispatch',
  'driver',
  'reception',
  'supervisor',
  'admin'
);

CREATE TYPE public.asset_status AS ENUM (
  'registered',
  'available',
  'packed',
  'dispatched',
  'in_transit',
  'received',
  'exception'
);

CREATE TYPE public.physical_condition AS ENUM (
  'unknown',
  'good',
  'pre_damaged',
  'damaged'
);

CREATE TYPE public.transfer_unit_type AS ENUM ('pallet', 'box', 'container');

CREATE TYPE public.transfer_unit_status AS ENUM (
  'open',
  'sealed',
  'assigned',
  'dispatched',
  'in_transit',
  'received',
  'exception'
);

CREATE TYPE public.trip_status AS ENUM (
  'planned',
  'loading',
  'ready',
  'dispatched',
  'in_transit',
  'received',
  'closed',
  'cancelled'
);

CREATE TYPE public.receipt_status AS ENUM (
  'open',
  'with_discrepancies',
  'conform',
  'closed'
);

CREATE TYPE public.discrepancy_type AS ENUM (
  'missing',
  'damaged',
  'unexpected',
  'seal_broken'
);

CREATE TYPE public.sync_command_status AS ENUM (
  'pending',
  'accepted',
  'conflict',
  'rejected'
);

CREATE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  email text NOT NULL,
  display_name text NOT NULL,
  rut text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_email_not_blank CHECK (btrim(email) <> ''),
  CONSTRAINT profiles_display_name_not_blank CHECK (btrim(display_name) <> ''),
  CONSTRAINT profiles_rut_not_blank CHECK (rut IS NULL OR btrim(rut) <> '')
);

CREATE UNIQUE INDEX profiles_email_unique ON public.profiles (lower(email));
CREATE UNIQUE INDEX profiles_rut_unique ON public.profiles (upper(rut))
  WHERE rut IS NOT NULL;

CREATE TABLE public.user_roles (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  role public.app_role NOT NULL,
  active boolean NOT NULL DEFAULT true,
  assigned_by uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

CREATE TABLE public.locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT locations_code_not_blank CHECK (btrim(code) <> ''),
  CONSTRAINT locations_name_not_blank CHECK (btrim(name) <> '')
);

CREATE UNIQUE INDEX locations_code_unique ON public.locations (upper(code));

CREATE TABLE public.areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id uuid NOT NULL REFERENCES public.locations(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT areas_code_not_blank CHECK (btrim(code) <> ''),
  CONSTRAINT areas_name_not_blank CHECK (btrim(name) <> ''),
  UNIQUE (location_id, code)
);

CREATE TABLE public.transfer_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  source_location_id uuid NOT NULL REFERENCES public.locations(id) ON DELETE RESTRICT,
  destination_location_id uuid NOT NULL REFERENCES public.locations(id) ON DELETE RESTRICT,
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT transfer_operations_code_not_blank CHECK (btrim(code) <> ''),
  CONSTRAINT transfer_operations_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT transfer_operations_distinct_locations CHECK (source_location_id <> destination_location_id),
  CONSTRAINT transfer_operations_dates_valid CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
);

CREATE UNIQUE INDEX transfer_operations_code_unique
  ON public.transfer_operations (upper(code));

CREATE TABLE public.assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_code text NOT NULL,
  qr_code text NOT NULL,
  description text NOT NULL,
  current_location_id uuid REFERENCES public.locations(id) ON DELETE RESTRICT,
  origin_area_id uuid REFERENCES public.areas(id) ON DELETE RESTRICT,
  status public.asset_status NOT NULL DEFAULT 'registered',
  active boolean NOT NULL DEFAULT true,
  master_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assets_asset_code_not_blank CHECK (btrim(asset_code) <> ''),
  CONSTRAINT assets_qr_code_not_blank CHECK (btrim(qr_code) <> ''),
  CONSTRAINT assets_description_not_blank CHECK (btrim(description) <> ''),
  CONSTRAINT assets_master_data_object CHECK (jsonb_typeof(master_data) = 'object')
);

CREATE UNIQUE INDEX assets_asset_code_unique ON public.assets (upper(asset_code));
CREATE UNIQUE INDEX assets_qr_code_unique ON public.assets (qr_code);
CREATE INDEX assets_origin_area_idx ON public.assets (origin_area_id);
CREATE INDEX assets_status_idx ON public.assets (status);

CREATE TABLE public.origin_handoffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL REFERENCES public.transfer_operations(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE RESTRICT,
  area_id uuid NOT NULL REFERENCES public.areas(id) ON DELETE RESTRICT,
  responsible_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  initial_condition public.physical_condition NOT NULL,
  observations text,
  handed_over_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (operation_id, asset_id)
);

CREATE TABLE public.transfer_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL REFERENCES public.transfer_operations(id) ON DELETE RESTRICT,
  unit_code text NOT NULL,
  unit_type public.transfer_unit_type NOT NULL,
  master_qr text,
  status public.transfer_unit_status NOT NULL DEFAULT 'open',
  seal_number text,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  sealed_by uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  sealed_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT transfer_units_code_not_blank CHECK (btrim(unit_code) <> ''),
  CONSTRAINT transfer_units_version_positive CHECK (version > 0),
  CONSTRAINT transfer_units_seal_complete CHECK (
    (status = 'open' AND seal_number IS NULL AND sealed_by IS NULL AND sealed_at IS NULL)
    OR
    (status <> 'open' AND seal_number IS NOT NULL AND sealed_by IS NOT NULL AND sealed_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX transfer_units_code_unique
  ON public.transfer_units (operation_id, upper(unit_code));
CREATE UNIQUE INDEX transfer_units_master_qr_unique
  ON public.transfer_units (master_qr)
  WHERE master_qr IS NOT NULL;
CREATE UNIQUE INDEX transfer_units_seal_number_unique
  ON public.transfer_units (upper(seal_number))
  WHERE seal_number IS NOT NULL;
CREATE INDEX transfer_units_status_idx ON public.transfer_units (status);

CREATE TABLE public.unit_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id uuid NOT NULL REFERENCES public.transfer_units(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE RESTRICT,
  added_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  added_at timestamptz NOT NULL DEFAULT now(),
  removed_by uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  removed_at timestamptz,
  removal_reason text,
  CONSTRAINT unit_assets_removal_complete CHECK (
    (removed_at IS NULL AND removed_by IS NULL AND removal_reason IS NULL)
    OR
    (removed_at IS NOT NULL AND removed_by IS NOT NULL AND btrim(removal_reason) <> '')
  )
);

CREATE UNIQUE INDEX unit_assets_active_asset_unique
  ON public.unit_assets (asset_id)
  WHERE removed_at IS NULL;
CREATE UNIQUE INDEX unit_assets_active_pair_unique
  ON public.unit_assets (unit_id, asset_id)
  WHERE removed_at IS NULL;
CREATE INDEX unit_assets_unit_idx ON public.unit_assets (unit_id);

CREATE TABLE public.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plate text NOT NULL,
  description text,
  capacity_kg numeric(12, 2),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vehicles_plate_not_blank CHECK (btrim(plate) <> ''),
  CONSTRAINT vehicles_capacity_positive CHECK (capacity_kg IS NULL OR capacity_kg > 0)
);

CREATE UNIQUE INDEX vehicles_plate_unique ON public.vehicles (upper(plate));

CREATE TABLE public.trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL REFERENCES public.transfer_operations(id) ON DELETE RESTRICT,
  trip_code text NOT NULL,
  vehicle_id uuid NOT NULL REFERENCES public.vehicles(id) ON DELETE RESTRICT,
  driver_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  status public.trip_status NOT NULL DEFAULT 'planned',
  planned_departure_at timestamptz NOT NULL,
  departed_at timestamptz,
  arrived_at timestamptz,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  manifest_frozen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT trips_code_not_blank CHECK (btrim(trip_code) <> ''),
  CONSTRAINT trips_actual_dates_valid CHECK (arrived_at IS NULL OR departed_at IS NULL OR arrived_at >= departed_at)
);

CREATE UNIQUE INDEX trips_code_unique ON public.trips (operation_id, upper(trip_code));
CREATE INDEX trips_status_idx ON public.trips (status);

CREATE TABLE public.trip_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE RESTRICT,
  unit_id uuid NOT NULL REFERENCES public.transfer_units(id) ON DELETE RESTRICT,
  attached_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  attached_at timestamptz NOT NULL DEFAULT now(),
  detached_by uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  detached_at timestamptz,
  detachment_reason text,
  CONSTRAINT trip_units_detachment_complete CHECK (
    (detached_at IS NULL AND detached_by IS NULL AND detachment_reason IS NULL)
    OR
    (detached_at IS NOT NULL AND detached_by IS NOT NULL AND btrim(detachment_reason) <> '')
  )
);

CREATE UNIQUE INDEX trip_units_active_unit_unique
  ON public.trip_units (unit_id)
  WHERE detached_at IS NULL;
CREATE UNIQUE INDEX trip_units_active_pair_unique
  ON public.trip_units (trip_id, unit_id)
  WHERE detached_at IS NULL;
CREATE INDEX trip_units_trip_idx ON public.trip_units (trip_id);

CREATE TABLE public.custody_acceptances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE RESTRICT,
  driver_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  seals_intact boolean NOT NULL,
  observations text,
  accepted_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX custody_acceptances_trip_unique
  ON public.custody_acceptances (trip_id);

CREATE TABLE public.receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE RESTRICT,
  status public.receipt_status NOT NULL DEFAULT 'open',
  received_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  act_number text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trip_id),
  CONSTRAINT receipts_close_complete CHECK (
    (status IN ('open', 'with_discrepancies') AND closed_at IS NULL)
    OR
    (status IN ('conform', 'closed') AND closed_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX receipts_act_number_unique
  ON public.receipts (upper(act_number))
  WHERE act_number IS NOT NULL;

CREATE TABLE public.receipt_units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id uuid NOT NULL REFERENCES public.receipts(id) ON DELETE RESTRICT,
  unit_id uuid NOT NULL REFERENCES public.transfer_units(id) ON DELETE RESTRICT,
  seal_intact boolean NOT NULL,
  verified_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  verified_at timestamptz NOT NULL,
  notes text,
  UNIQUE (receipt_id, unit_id)
);

CREATE TABLE public.receipt_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id uuid NOT NULL REFERENCES public.receipts(id) ON DELETE RESTRICT,
  asset_id uuid NOT NULL REFERENCES public.assets(id) ON DELETE RESTRICT,
  condition public.physical_condition NOT NULL,
  present boolean NOT NULL,
  verified_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  verified_at timestamptz NOT NULL,
  notes text,
  UNIQUE (receipt_id, asset_id)
);

CREATE TABLE public.discrepancies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id uuid NOT NULL REFERENCES public.receipts(id) ON DELETE RESTRICT,
  discrepancy_type public.discrepancy_type NOT NULL,
  asset_id uuid REFERENCES public.assets(id) ON DELETE RESTRICT,
  unit_id uuid REFERENCES public.transfer_units(id) ON DELETE RESTRICT,
  description text NOT NULL,
  reported_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  reported_at timestamptz NOT NULL DEFAULT now(),
  resolved_by uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  resolved_at timestamptz,
  resolution text,
  CONSTRAINT discrepancies_description_not_blank CHECK (btrim(description) <> ''),
  CONSTRAINT discrepancies_subject_present CHECK (asset_id IS NOT NULL OR unit_id IS NOT NULL),
  CONSTRAINT discrepancies_resolution_complete CHECK (
    (resolved_at IS NULL AND resolved_by IS NULL AND resolution IS NULL)
    OR
    (resolved_at IS NOT NULL AND resolved_by IS NOT NULL AND btrim(resolution) <> '')
  )
);

CREATE INDEX discrepancies_receipt_idx ON public.discrepancies (receipt_id);

CREATE TABLE public.discrepancy_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discrepancy_id uuid NOT NULL REFERENCES public.discrepancies(id) ON DELETE RESTRICT,
  storage_path text NOT NULL UNIQUE,
  content_type text NOT NULL,
  uploaded_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  captured_at timestamptz,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT discrepancy_photos_path_not_blank CHECK (btrim(storage_path) <> ''),
  CONSTRAINT discrepancy_photos_supported_type CHECK (
    content_type IN ('image/jpeg', 'image/png', 'image/webp')
  )
);

CREATE TABLE public.sync_commands (
  command_id uuid PRIMARY KEY,
  device_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  local_sequence bigint NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id uuid,
  expected_version integer,
  command_type text NOT NULL,
  payload jsonb NOT NULL,
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  status public.sync_command_status NOT NULL DEFAULT 'pending',
  result jsonb,
  error_code text,
  error_detail text,
  processed_at timestamptz,
  CONSTRAINT sync_commands_device_not_blank CHECK (btrim(device_id) <> ''),
  CONSTRAINT sync_commands_local_sequence_nonnegative CHECK (local_sequence >= 0),
  CONSTRAINT sync_commands_expected_version_positive CHECK (expected_version IS NULL OR expected_version > 0),
  CONSTRAINT sync_commands_aggregate_type_not_blank CHECK (btrim(aggregate_type) <> ''),
  CONSTRAINT sync_commands_command_type_not_blank CHECK (btrim(command_type) <> ''),
  CONSTRAINT sync_commands_payload_object CHECK (jsonb_typeof(payload) = 'object'),
  CONSTRAINT sync_commands_result_object CHECK (result IS NULL OR jsonb_typeof(result) = 'object'),
  CONSTRAINT sync_commands_processing_complete CHECK (
    (status = 'pending' AND processed_at IS NULL)
    OR
    (status <> 'pending' AND processed_at IS NOT NULL)
  ),
  UNIQUE (device_id, local_sequence)
);

CREATE INDEX sync_commands_status_received_idx
  ON public.sync_commands (status, received_at);
CREATE INDEX sync_commands_aggregate_idx
  ON public.sync_commands (aggregate_type, aggregate_id);

CREATE TABLE public.traceability_events (
  sequence bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  command_id uuid REFERENCES public.sync_commands(command_id) ON DELETE RESTRICT,
  operation_id uuid REFERENCES public.transfer_operations(id) ON DELETE RESTRICT,
  asset_id uuid REFERENCES public.assets(id) ON DELETE RESTRICT,
  unit_id uuid REFERENCES public.transfer_units(id) ON DELETE RESTRICT,
  trip_id uuid REFERENCES public.trips(id) ON DELETE RESTRICT,
  receipt_id uuid REFERENCES public.receipts(id) ON DELETE RESTRICT,
  event_type text NOT NULL,
  actor_user_id uuid NOT NULL,
  occurred_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT traceability_events_type_not_blank CHECK (btrim(event_type) <> ''),
  CONSTRAINT traceability_events_subject_present CHECK (
    asset_id IS NOT NULL
    OR unit_id IS NOT NULL
    OR trip_id IS NOT NULL
    OR receipt_id IS NOT NULL
  ),
  CONSTRAINT traceability_events_metadata_object CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX traceability_events_command_type_unique
  ON public.traceability_events (command_id, event_type)
  WHERE command_id IS NOT NULL;
CREATE INDEX traceability_events_asset_timeline_idx
  ON public.traceability_events (asset_id, sequence)
  WHERE asset_id IS NOT NULL;
CREATE INDEX traceability_events_unit_timeline_idx
  ON public.traceability_events (unit_id, sequence)
  WHERE unit_id IS NOT NULL;
CREATE INDEX traceability_events_trip_timeline_idx
  ON public.traceability_events (trip_id, sequence)
  WHERE trip_id IS NOT NULL;

CREATE FUNCTION public.prevent_traceability_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'traceability_events is append-only';
END;
$$;

CREATE TRIGGER traceability_events_no_update_or_delete
BEFORE UPDATE OR DELETE ON public.traceability_events
FOR EACH ROW EXECUTE FUNCTION public.prevent_traceability_event_mutation();

CREATE TRIGGER traceability_events_no_truncate
BEFORE TRUNCATE ON public.traceability_events
FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_traceability_event_mutation();

CREATE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, NEW.id::text),
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'display_name', ''), NEW.email, NEW.id::text)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE FUNCTION public.has_any_app_role(required_roles public.app_role[])
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

CREATE TRIGGER profiles_set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER locations_set_updated_at
BEFORE UPDATE ON public.locations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER areas_set_updated_at
BEFORE UPDATE ON public.areas
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER transfer_operations_set_updated_at
BEFORE UPDATE ON public.transfer_operations
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER assets_set_updated_at
BEFORE UPDATE ON public.assets
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER transfer_units_set_updated_at
BEFORE UPDATE ON public.transfer_units
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER vehicles_set_updated_at
BEFORE UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trips_set_updated_at
BEFORE UPDATE ON public.trips
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER receipts_set_updated_at
BEFORE UPDATE ON public.receipts
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfer_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.origin_handoffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfer_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unit_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custody_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discrepancies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discrepancy_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.traceability_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_read_own
ON public.profiles
FOR SELECT
TO authenticated
USING (
  id = auth.uid()
  OR public.has_any_app_role(ARRAY['supervisor', 'admin']::public.app_role[])
);

CREATE POLICY user_roles_read_own
ON public.user_roles
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.has_any_app_role(ARRAY['supervisor', 'admin']::public.app_role[])
);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'incident-photos',
  'incident-photos',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY incident_photos_insert_by_reception
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'incident-photos'
  AND owner_id = auth.uid()::text
  AND public.has_any_app_role(
    ARRAY['reception', 'supervisor', 'admin']::public.app_role[]
  )
);

CREATE POLICY incident_photos_read_by_authorized_roles
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'incident-photos'
  AND public.has_any_app_role(
    ARRAY['reception', 'supervisor', 'admin']::public.app_role[]
  )
);

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.profiles, public.user_roles TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_any_app_role(public.app_role[]) TO authenticated;

GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
REVOKE UPDATE, DELETE, TRUNCATE ON public.traceability_events FROM service_role;
GRANT SELECT, INSERT ON public.traceability_events TO service_role;

COMMIT;
