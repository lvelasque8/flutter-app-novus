# Novus — guía rápida para la demo

## Instalar en la tablet

1. Copia `dist/Novus-1.0.0-tablet.apk` a la tablet (cable USB, Google Drive o
   WhatsApp).
2. Abre el archivo y permite “Instalar apps desconocidas” si Android lo pide.
3. La app aparece como **Novus**.

También puedes instalarla por ADB:

```bash
adb install -r dist/Novus-1.0.0-tablet.apk
```

## Primer arranque

1. Escribe el nombre del negocio (por ejemplo, “Bodega La Esquina”).
2. Opcional: RIF, teléfono y dirección.
3. Introduce la **tasa BCV** del día (Bs por USD). Sin tasa no se muestran los
   montos en bolívares.
4. Deja el IVA en **16** (puedes cambiarlo a 0 si tus precios ya lo incluyen).
5. Pulsa **Comenzar a usar Novus**.

## Recorrido sugerido para la demo

1. **Inventario → Cargar productos de ejemplo**: carga 8 productos típicos.
2. **Vender**: toca productos para agregarlos al carrito. En horizontal verás
   el catálogo a la izquierda y el carrito a la derecha.
3. **Cobrar**: elige Efectivo Bs, Efectivo USD, Pago Móvil, Transferencia,
   Punto de venta o Fiado.
4. Si eliges **Fiado**, crea un cliente. La venta queda en **Cuentas**.
5. **Cuentas → cliente → Registrar abono**: registra un pago parcial o total.
6. **Ventas → venta → Imprimir / compartir nota**: genera el PDF con la leyenda
   “DOCUMENTO NO FISCAL”.

## Qué funciona

- Inventario con stock, stock mínimo, búsqueda y edición.
- Ventas con IVA configurable, descuento y doble moneda (USD/Bs).
- Cuentas por cobrar con abonos y saldo por cliente.
- Nota de entrega/recibo en PDF para imprimir o compartir.
- Inicio con ventas del día, cuentas pendientes y stock bajo.
- Todo funciona sin internet y los datos quedan en la tablet.

## Limitaciones de esta versión

- Está pensada para **una sola caja/tablet**.
- Todavía no hay exportación/restauración de respaldo.
- No emite facturación fiscal (SENIAT); solo documentos no fiscales.
- La app no tiene bloqueo por PIN ni usuarios/roles.

## Firma de la aplicación

El APK de `dist/` está firmado con el keystore `android/novus-release.jks`
(alias `novus`). Las credenciales están en `android/key.properties`, que **no
se sube al repositorio**.

Guarda una copia segura de `android/novus-release.jks` y de
`android/key.properties`: sin ellos no podrás publicar actualizaciones que
conserven los datos instalados.

## Datos de la demo

Los productos de ejemplo son locales y se pueden borrar desde
**Ajustes → Borrar ventas, productos y clientes**.
