# App Traslado

Sistema de trazabilidad integral para el traslado físico de bienes y activos desde Fantasilandia hacia Parque Sur.

## Infraestructura

El proyecto utiliza Supabase para PostgreSQL, autenticación y almacenamiento privado de fotografías. Las operaciones de negocio deben pasar por la API; la PWA no escribe directamente en las tablas de trazabilidad.

### Requisitos locales

- Node.js LTS
- Docker Desktop
- Supabase CLI mediante `npx supabase`

### Inicio local

```powershell
Copy-Item .env.example .env
npx supabase start
npx supabase db reset
```

La configuración, las migraciones y las políticas de seguridad están documentadas en [supabase/README.md](supabase/README.md).

## Documentación

- [Registro de cambios](CHANGELOG.md)
- [Configuración y operación de Supabase](supabase/README.md)

Todo cambio de código, infraestructura, seguridad o configuración debe incluir su documentación en el mismo commit.
