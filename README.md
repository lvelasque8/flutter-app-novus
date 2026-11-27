# Novus

**Control de inventario y ventas para negocios venezolanos.**

Novus es una aplicación de punto de venta para una sola caja, pensada para
usarse en una tablet Android. Guarda todo en el dispositivo (SQLite) y está
preparada para agregar sincronización en una fase posterior.

## Funcionalidad de esta primera versión

- **Inventario**: alta, edición, búsqueda por nombre/código/categoría,
  control de stock y alertas de stock bajo. Incluye **categorías rápidas**,
  **SKU automático**, validación de código de barras/SKU duplicados y
  **Guardar y agregar otro** para cargar varios productos seguidos.
- **Lector de código de barras**: escanea con la cámara desde el POS o al
  cargar un producto y lo agrega al carrito automáticamente.
- **Ventas**: catálogo táctil, carrito, descuentos, IVA configurable y cobro en
  efectivo (Bs/USD), Pago Móvil, transferencia, punto de venta o fiado.
  Incluye **anulación de ventas** con devolución de stock.
- **Devoluciones parciales**: desde el detalle de la venta se elige cuántas
  unidades devolver de cada producto. Repone el stock, registra el movimiento,
  ajusta caja y reportes y, si la venta fue fiada, abona el monto a la cuenta
  del cliente.
- **Pagos combinados**: reparte el total entre varios métodos y deja el resto
  como fiado. Ejemplo: $1,00 en efectivo + $2,48 por Pago Móvil, o efectivo +
  fiado parcial.
- **Doble moneda**: precios en dólares y equivalente en bolívares con la tasa
  BCV configurada.
- **Cuentas por cobrar**: fiados por cliente, saldo, historial de abonos y
  registro de pagos parciales. Incluye **Saldar cuenta** para cobrar el saldo
  completo sin escribir el monto, **límite de crédito** por cliente,
  **edición de los datos del cliente**, **vencimiento de fiados** y
  **cobranza automática** con recordatorios por WhatsApp.
- **Cobranza**: cada fiado nuevo vence según el plazo configurado (15 días por
  defecto). La pestaña **Cobranza** agrupa las cuentas vencidas y por vencer,
  muestra el monto y permite enviar un recordatorio por WhatsApp con un toque.
  El inicio avisa cuando hay cuentas vencidas.
- **Datos de pago en WhatsApp**: banco, cuenta, titular, cédula/RIF, Pago Móvil
  y una nota opcional. Se activan o desactivan con un interruptor en Ajustes y
  se agregan al estado de cuenta o al recordatorio.
- **Notas de entrega / recibos no fiscales**: PDF imprimible o compartible con
  correlativo, datos del negocio, ítems, totales y leyenda **“Documento no
  fiscal”**.
- **Impresión térmica Bluetooth**: ticket ESC/POS directo en impresoras de
  58 mm u 80 mm, con prueba de impresión desde Ajustes.
- **Cierre de caja**: apertura con fondo, ventas del turno, efectivo esperado
  en Bs/USD, conteo físico y diferencia.
- **Reportes por fecha**: ventas y montos cobrados por método de pago
  (Punto de venta, Efectivo Bs/USD, Pago Móvil, transferencia y fiado),
  productos más vendidos y ventas por día.
- **Respaldo y restauración**: exporta la base por el menú de compartir y
  restaura un archivo `.db` desde Ajustes.
- **Importar inventario desde Excel**: descarga la plantilla, revisa una vista
  previa y crea o actualiza productos por código de barras, SKU o nombre. El
  stock se ajusta con su movimiento registrado.
- **Panel remoto (solo consulta)**: sube los cambios a tu proyecto de Supabase
  y permite ver ventas, cuentas, inventario y caja desde el teléfono o la
  computadora. La tablet sigue siendo la única que vende y edita.
- **Tasa BCV automática**: consulta la tasa oficial del día al abrir la app,
  con la API como respaldo y opción manual para ajustarla.
- **Inicio**: ventas del día, cuentas por cobrar, stock bajo y últimas ventas.
- **Ajustes**: datos del negocio, RIF, teléfono, dirección, tasa BCV, IVA,
  días de plazo para fiados, datos de pago para WhatsApp e impresora térmica.

## Cómo funciona el almacenamiento

La base de datos local es la fuente de verdad. Cada venta, producto, cliente y
abono se escribe en SQLite. Los datos quedan guardados en el dispositivo.

> Importante: esta versión está pensada para **una sola tablet**. El panel
> remoto es de solo lectura; vender o editar desde otro dispositivo queda para
> una fase posterior. El esquema ya incluye fechas, movimientos y una cola de
> cambios para facilitarlo.

## Requisitos

- Flutter 3.47 o superior (Dart 3.13).
- Android SDK 36.
- Tablet Android (la interfaz se adapta a horizontal y vertical).

## Ejecutar

```bash
flutter pub get
flutter run -d <id-del-dispositivo>
```

### Emulador (Windows)

Para abrir el AVD `NovusTablet` en una ventana que quepa en pantalla:

```powershell
powershell -ExecutionPolicy Bypass -File tools/abrir-emulador.ps1
```

Se puede ajustar el tamaño con `-Ancho 1100 -Alto 720`.

## Compilar el APK

```bash
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

> El APK de release se firma con `android/novus-release.jks` usando las
> credenciales de `android/key.properties`. Guarda ambos archivos: son
> necesarios para publicar actualizaciones que conserven los datos instalados.

## Panel remoto (solo consulta)

La tablet sube solo los cambios a Supabase (ventas, cuentas, inventario, caja y
ajustes) y un panel web permite consultarlos con la cuenta del dueño. Nunca
edita ni vende: la tablet sigue siendo la fuente de verdad.

1. Ejecutar `supabase/schema.sql` en el SQL Editor de tu proyecto.
2. Crear el usuario del dueño en **Authentication → Users**.
3. En la tablet: **Ajustes → Panel remoto → Conectar**.
4. Compilar y publicar el panel:

```bash
flutter build web --release -t lib/admin/main.dart
```

El detalle paso a paso está en [`supabase/README.md`](supabase/README.md).

## Estructura

```
lib/
├── app.dart
├── main.dart
├── admin/               # panel web de solo consulta
├── core/
│   ├── config/          # URL y clave pública de Supabase
│   ├── database/        # SQLite (esquema, cola de cambios y acceso)
│   ├── navigation/      # go_router
│   ├── shell/           # arranque, onboarding y navegación principal
│   ├── theme/           # sistema de diseño
│   └── utils/           # moneda y formatos es-VE
├── features/
│   ├── accounts/        # clientes, fiados y abonos
│   ├── dashboard/       # resumen del día
│   ├── documents/       # PDF de notas de entrega
│   ├── products/        # inventario
│   ├── sales/           # POS, carrito e historial
│   ├── settings/        # configuración del negocio
│   └── sync/            # subida de cambios al panel remoto
└── shared/widgets/      # átomos y moléculas reutilizables
```

## Base de datos

Tablas principales: `products`, `inventory_movements`, `sales`, `sale_items`,
`payments`, `sale_returns`, `sale_return_items`, `customers`, `accounts`,
`account_payments`, `cash_sessions`, `settings` y `sync_queue`.

`sync_queue` guarda qué filas cambiaron (altas, cambios y bajas) para subirlas
al panel remoto sin enviar toda la base.

El stock se calcula/actualiza con movimientos (`entrada`, `venta`, `ajuste`),
lo que deja trazabilidad y prepara el terreno para sincronización. Las ventas y
abonos guardan la sesión de caja a la que pertenecen.

## Próximos pasos

- Sincronización opcional (una caja hoy, varias después).
- Entradas y ajustes de inventario con historial.
- PIN/usuarios y roles.
- Facturación fiscal (SENIAT), fuera del alcance actual.
- Firma de release y publicación interna.

---

Hecho a partir de la arquitectura de `easy-sell-flutter-app`, reescrita para
Novus.
