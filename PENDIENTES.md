# Pendientes

Cosas anotadas para una próxima versión.

## Textos de cantidades (plurales) — ✅ hecho

Se corrigió el uso de "venta(s)" y "unidades" para que respeten el singular
y el plural: `1 venta`, `4 ventas`, `1 unidad`, `12 unidades`.

Se aplicó en Reportes, Inicio (Ventas de hoy / Cuentas por cobrar), Ventas
(historial) y Cuentas por cobrar, usando el helper `TextoPlural`
(`lib/core/utils/texto_plural.dart`) y su prueba en
`test/texto_plural_test.dart`.
