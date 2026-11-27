# Panel remoto (solo consulta)

Novus sube los cambios de la tablet a tu proyecto de Supabase y un panel web
permite consultarlos desde el teléfono o la computadora. La tablet sigue siendo
la única que vende y edita.

## 1. Crear el usuario del dueño

En Supabase → **Authentication → Users → Add user**:

- Correo y contraseña del dueño.
- Marca **Auto Confirm User** para no depender del correo de confirmación.

Ese mismo correo y contraseña se usan en la tablet y en el panel.

## 2. Crear el esquema

Supabase → **SQL Editor → New query**, pega completo `supabase/schema.sql` y
ejecuta. Crea:

- `businesses` y `business_members` (negocio y permisos).
- Las tablas espejo: ventas, ítems, pagos, devoluciones, clientes, cuentas,
  abonos, productos, movimientos, caja y ajustes.
- `sync_devices` para saber cuándo subió datos cada tablet.
- Permisos por fila (RLS): cada usuario solo ve su propio negocio.
- `ensure_business(...)`, que crea el negocio la primera vez.

## 3. Conectar la tablet

1. Instala el APK nuevo.
2. **Ajustes → Panel remoto → Conectar panel remoto**.
3. Correo y contraseña del dueño.
4. La primera subida puede tardar unos segundos si hay muchas ventas.

La sincronización se repite:

- Al abrir la app y al volver a ella.
- Cada 10 minutos mientras está abierta.
- 8 segundos después de una venta, un abono, una devolución o una anulación.
- Al pulsar **Sincronizar ahora**.

Solo se envían las filas que cambiaron (triggers locales en `sync_queue`), no la
base completa.

## 4. Publicar el panel

Compilar:

```bash
flutter build web --release -t lib/admin/main.dart
```

Subir el contenido de `build/web` a cualquier hosting estático:

- Netlify o Vercel (arrastrar la carpeta).
- GitHub Pages.
- Supabase Storage con un bucket público.

Cuando tengas la URL, agrégala en `lib/core/config/remote_config.dart`
(`panelUrl`) para que la tablet muestre el botón **Abrir panel**.

## Seguridad

- La clave `sb_publishable_...` es pública por diseño; la protección real es RLS.
- Nunca poner la `sb_secret_...` ni la `service_role` en la app ni en el panel.
- El panel es de solo lectura y exige sesión.
- Al desconectar la tablet deja de subir; lo ya subido permanece hasta que se
  borre desde Supabase.
- Los datos de clientes (nombre, teléfono, cédula y saldos) viajan a tu propio
  proyecto de Supabase.

## Problemas comunes

| Síntoma | Causa probable |
|---|---|
| “Correo o contraseña incorrectos” | El usuario no existe o no está confirmado |
| “new row violates row-level security policy” | El esquema no se ejecutó o el usuario no es miembro |
| “La sincronización remota no está disponible” | La app arrancó sin internet; reiníciala con conexión |
| El panel entra pero no muestra nada | La tablet todavía no ha sincronizado |
| Cambios que no aparecen | Pulsa **Sincronizar ahora** y revisa “Cambios pendientes” |
