# Pendientes

Cosas anotadas para una próxima versión.

## Hecho

### Textos de cantidades (plurales) — ✅

Se corrigió el uso de "venta(s)" y "unidades" para que respeten el singular
y el plural: `1 venta`, `4 ventas`, `1 unidad`, `12 unidades`.

Se aplicó en Reportes, Inicio (Ventas de hoy / Cuentas por cobrar), Ventas
(historial) y Cuentas por cobrar, usando el helper `TextoPlural`
(`lib/core/utils/texto_plural.dart`) y su prueba en
`test/texto_plural_test.dart`.

### Lector de código de barras por cámara — ✅

- Botón de escanear en el buscador del POS: agrega el producto al carrito.
- Botón de escanear en el formulario de producto.
- Formatos: EAN-13, EAN-8, UPC-A/E, Code 128/39/93, ITF, Codabar y QR.
- Requiere permiso de cámara (se pide al abrir el lector).

### Impresión térmica Bluetooth — ✅

- Ticket ESC/POS de 58 mm u 80 mm por Bluetooth.
- Ajustes → Impresora térmica: elegir impresora emparejada, ancho de papel
  y ticket de prueba.
- Botón "Imprimir ticket" al terminar una venta y en el detalle de venta.
- Requiere emparejar la impresora desde los ajustes de Android.

### Carga rápida de productos — ✅

- Chips de categorías sugeridas (Alimentos, Bebidas, Lácteos, etc.) más las
  categorías que ya usaste.
- SKU automático por categoría (`ALI-0001`) si se deja vacío.
- Aviso si se repite el código de barras o el SKU.
- Botón "Guardar y agregar otro" para cargar varios productos seguidos.

### Emulador en ventana cómoda — ✅

- `tools/abrir-emulador.ps1` abre `NovusTablet` y fija la ventana en
  1050×690 (ajustable con `-Ancho` y `-Alto`).

### Anulación de ventas — ✅

- Botón "Anular venta" en el detalle de la venta, con motivo opcional.
- Devuelve el stock y registra el movimiento `anulacion`.
- La venta deja de sumar en caja, reportes, inicio y cuentas por cobrar.
- Se anula el fiado asociado. No se permite si la cuenta ya tiene abonos.
- El historial marca la venta como "Anulada".

### Límite de crédito por cliente — ✅

- Campo "Límite de crédito (USD)" en el formulario de cliente.
- El diálogo de cobro muestra saldo actual, límite y saldo después del fiado.
- Bloquea el cobro si el fiado supera el límite (también se valida al guardar).
- El detalle de la cuenta muestra el límite y avisa si está excedido.

## Pendiente

- Devoluciones parciales (por producto).
- Entradas y ajustes de inventario con historial.
- Gastos del negocio y compras a proveedores.
- Límite de crédito y vencimiento de fiados.
- Respaldo automático.
- PIN/usuarios y roles.
- Impresión por USB/red (hoy solo Bluetooth).
- Importar/exportar inventario en CSV.
