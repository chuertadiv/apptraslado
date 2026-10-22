# Herramientas del proyecto

Este documento registra las herramientas adoptadas o previstas, su propósito y sus límites de costo. Se priorizan alternativas gratuitas y open source durante el desarrollo.

## Control de versiones y automatización

- Git: control de versiones local, open source.
- GitHub Free: repositorio, pull requests y gestión básica. Los repositorios privados también están disponibles; GitHub Actions posee cuotas mensuales.
- GitHub Actions: validación automática de migraciones mediante `.github/workflows/supabase-ci.yml`.

## Plataforma de datos

- PostgreSQL: base de datos relacional open source.
- Supabase Free: PostgreSQL, Auth y Storage para desarrollo.
- Supabase CLI: migraciones, configuración, lint y entorno local; open source.

El plan gratuito es apropiado para desarrollo y demostraciones. Antes de producción se deben evaluar Pro, backups descargables, PITR, disponibilidad y soporte.

## Backend previsto

- Node.js LTS y TypeScript: runtime y lenguaje open source.
- NestJS con Fastify: API y adaptador HTTP open source.
- Drizzle ORM: acceso tipado a PostgreSQL, open source.
- Zod: validación y contratos compartidos, open source.
- OpenAPI y Scalar o Swagger UI: contrato y documentación HTTP, open source.

## PWA prevista

- React, Vite y Tailwind CSS: interfaz y compilación, open source.
- TanStack Query y Router: datos remotos y navegación, open source.
- React Hook Form y Zod: formularios y validación, open source.
- Dexie e IndexedDB: cola offline local, open source y API nativa.
- Workbox: service worker y caché PWA, open source.
- ZXing: lectura de códigos QR por cámara, open source.
- Zustand: estado local, open source.

## Monorepo y calidad

- pnpm Workspaces: dependencias y workspace, open source.
- Turborepo: ejecución coordinada de tareas, open source.
- Vitest: pruebas unitarias, open source.
- Playwright: pruebas de interfaz, open source.
- Supertest: pruebas HTTP, open source.
- Testcontainers: integración con PostgreSQL, open source.
- k6: pruebas de carga locales, open source.
- Bruno: colecciones API versionadas, open source.

## Contenedores locales

Supabase local requiere un runtime compatible con Docker:

- Docker Engine es open source en Linux.
- Docker Desktop puede requerir licencia según el tamaño y tipo de organización.
- Rancher Desktop y Podman Desktop son alternativas open source, pero su compatibilidad con Supabase CLI debe validarse antes de adoptarlas.

No se incorporará una herramienta con costo de licencia sin revisión previa.

## Rutinas actuales

```powershell
# Iniciar servicios locales
npx supabase start

# Reconstruir la base desde migraciones y seed
npx supabase db reset

# Validar SQL local
npx supabase db lint --local --level warning

# Comparar configuración local y remota
npx supabase config diff

# Revisar migraciones locales y remotas
npx supabase migration list
```

## Criterio para nuevas herramientas

Cada incorporación debe documentar:

1. Problema que resuelve.
2. Alternativas gratuitas evaluadas.
3. Licencia o límites del plan gratuito.
4. Datos enviados a terceros.
5. Procedimiento de instalación y actualización.
6. Costos o cambios necesarios para producción.
