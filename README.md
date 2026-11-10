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
- **Pagos combinados**: reparte el total entre varios métodos y deja el resto
  como fiado. Ejemplo: $1,00 en efectivo + $2,48 por Pago Móvil, o efectivo +
  fiado parcial.
- **Doble moneda**: precios en dólares y equivalente en bolívares con la tasa
  BCV configurada.
- **Cuentas por cobrar**: fiados por cliente, saldo, historial de abonos y
  registro de pagos parciales. Incluye **Saldar cuenta** para cobrar el saldo
  completo sin escribir el monto, **límite de crédito** por cliente,
  **edición de los datos del cliente** y **envío del estado de cuenta por
  WhatsApp**.
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
- **Tasa BCV automática**: consulta la tasa oficial del día al abrir la app,
  con la API como respaldo y opción manual para ajustarla.
- **Inicio**: ventas del día, cuentas por cobrar, stock bajo y últimas ventas.
- **Ajustes**: datos del negocio, RIF, teléfono, dirección, tasa BCV, IVA e
  impresora térmica.

## Cómo funciona el almacenamiento

La base de datos local es la fuente de verdad. Cada venta, producto, cliente y
abono se escribe en SQLite. Los datos quedan guardados en el dispositivo.

> Importante: esta versión está pensada para **una sola tablet**. Sincronización
> entre dispositivos y respaldo en la nube quedan para la siguiente fase; el
> esquema ya incluye fechas y movimientos para facilitarlo.

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

## Estructura

```
lib/
├── app.dart
├── main.dart
├── core/
│   ├── database/        # SQLite (esquema y acceso)
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
│   └── settings/        # configuración del negocio
└── shared/widgets/      # átomos y moléculas reutilizables
```

## Base de datos

Tablas principales: `products`, `inventory_movements`, `sales`, `sale_items`,
`payments`, `customers`, `accounts`, `account_payments`, `cash_sessions` y
`settings`.

El stock se calcula/actualiza con movimientos (`entrada`, `venta`, `ajuste`),
lo que deja trazabilidad y prepara el terreno para sincronización. Las ventas y
abonos guardan la sesión de caja a la que pertenecen.

## Próximos pasos

- Sincronización opcional (una caja hoy, varias después).
- Anulación y devoluciones de ventas.
- Entradas y ajustes de inventario con historial.
- PIN/usuarios y roles.
- Facturación fiscal (SENIAT), fuera del alcance actual.
- Firma de release y publicación interna.

---

Hecho a partir de la arquitectura de `easy-sell-flutter-app`, reescrita para
Novus.
