BEGIN;

INSERT INTO public.locations (code, name)
VALUES
  ('FANTASILANDIA', 'Fantasilandia'),
  ('PARQUE_SUR', 'Parque Sur')
ON CONFLICT DO NOTHING;

COMMIT;
