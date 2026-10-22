# Registro de cambios

Todos los cambios relevantes del proyecto se documentan en este archivo. El formato sigue los principios de Keep a Changelog.

## Sin publicar

### Documentación

- Se incorporó una regla permanente que exige actualizar documentación, contratos y registro de cambios en cada implementación.

## 2026-10-22

### Añadido

- Repositorio inicial y documentación básica.
- Configuración local de Supabase y proyecto remoto en São Paulo.
- Esquema inicial de trazabilidad con activos, unidades, viajes, recepción, discrepancias y sincronización offline.
- Autenticación, roles polifuncionales, políticas RLS y almacenamiento privado de fotografías.
- Bitácora append-only `traceability_events`.
- Integración entre GitHub y Supabase.
- Workflow de GitHub Actions para reconstruir y validar las migraciones.

### Seguridad

- Registro público de usuarios deshabilitado.
- Contraseñas de al menos 12 caracteres y cambio seguro habilitado.
- SSL obligatorio para conexiones PostgreSQL.
- Función de autorización trasladada a un esquema privado.
- Auditoría de seguridad y lint SQL ejecutados sin observaciones.
