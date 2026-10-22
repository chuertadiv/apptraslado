# Supabase

## Responsabilidades

Supabase proporciona:

- PostgreSQL administrado.
- Supabase Auth para identidad.
- Storage privado para fotografías de discrepancias.

La API de la aplicación conserva las reglas de negocio, la idempotencia offline y la escritura de la bitácora `traceability_events`. La clave secreta o `service_role` nunca debe llegar a la PWA.

## Desarrollo local

Docker Desktop debe estar instalado y en ejecución.

```powershell
npx supabase start
npx supabase db reset
npx supabase db lint --local
```

`db reset` aplica todas las migraciones y luego ejecuta `seed.sql`.

## Ambientes

- Local: Supabase CLI.
- Staging: proyecto independiente o rama persistente.
- Producción: proyecto Pro independiente en `sa-east-1`.

Cada ambiente mantiene claves y URLs distintas. No se copian usuarios ni datos operativos de producción a desarrollo.

## Migraciones

Los cambios de esquema se realizan exclusivamente mediante archivos en `supabase/migrations`.

```powershell
npx supabase migration new nombre_del_cambio
npx supabase db reset
npx supabase db lint --local
```

No se modifica el esquema de producción manualmente desde Studio. Si ocurre una corrección excepcional, se debe recuperar inmediatamente como una migración versionada.

## Vinculación remota

```powershell
npx supabase login --token <ACCESS_TOKEN>
npx supabase link --project-ref <PROJECT_REF>
npx supabase db push --dry-run
```

El token se obtiene en Supabase Dashboard, Account Settings, Access Tokens. No debe guardarse en archivos del repositorio ni en el historial de la terminal compartida.

## GitHub

En Supabase Dashboard:

1. Abrir Project Settings, Integrations, GitHub Integration.
2. Autorizar únicamente `chuertadiv/apptraslado`.
3. Configurar `.` como working directory.
4. Usar `main` como rama de producción.
5. Habilitar despliegue a producción después de validar la migración en staging.

## Seguridad operativa

- El alta de usuarios es administrada; el registro público está deshabilitado.
- Todas las tablas de dominio tienen RLS habilitado.
- `anon` y `authenticated` no escriben directamente en tablas de dominio.
- Solo recepción, supervisión y administración pueden cargar o leer fotos.
- `traceability_events` rechaza `UPDATE`, `DELETE` y `TRUNCATE`.
- Los comandos offline usan `command_id` y `(device_id, local_sequence)` como claves idempotentes.

## Producción

Antes de operar bienes reales:

1. Pasar el proyecto a Pro o superior.
2. Activar Point-in-Time Recovery si el RPO requerido es menor a un día.
3. Configurar SMTP corporativo.
4. Exigir MFA a administradores del proyecto.
5. Mantener al menos dos propietarios corporativos.
6. Crear exportaciones externas periódicas y probar una restauración.
7. Revisar Performance Advisor, índices y límites de gasto.
