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

## Pendiente

- Anular ventas y devoluciones.
- Entradas y ajustes de inventario con historial.
- Gastos del negocio y compras a proveedores.
- Límite de crédito y vencimiento de fiados.
- Respaldo automático.
- PIN/usuarios y roles.
- Impresión por USB/red (hoy solo Bluetooth).
