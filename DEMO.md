# Novus — guía rápida para la demo

## Capturas

| Inicio | Vender |
|---|---|
| ![Inicio](docs/screenshots/01-inicio.png) | ![Vender](docs/screenshots/02-vender.png) |

| Inventario | Cuentas por cobrar |
|---|---|
| ![Inventario](docs/screenshots/03-inventario.png) | ![Cuentas](docs/screenshots/04-cuentas.png) |

| Nota de entrega (PDF) | Primer arranque |
|---|---|
| ![Nota](docs/screenshots/05-nota.png) | ![Onboarding](docs/screenshots/06-onboarding.png) |

| Cierre de caja | Reportes por fecha |
|---|---|
| ![Caja](docs/screenshots/07-caja.png) | ![Reportes](docs/screenshots/08-reportes.png) |

| Respaldo | Tasa BCV automática |
|---|---|
| ![Respaldo](docs/screenshots/09-respaldo.png) | ![Tasa](docs/screenshots/10-tasa.png) |

| Pago combinado | Detalle de la venta |
|---|---|
| ![Pago mixto](docs/screenshots/11-pago-mixto.png) | ![Detalle mixto](docs/screenshots/12-detalle-mixto.png) |

| Saldar cuenta | Cuenta pagada |
|---|---|
| ![Saldar](docs/screenshots/13-saldar-cuenta.png) | ![Pagada](docs/screenshots/14-cuenta-pagada.png) |

| Cobranza | Devolver productos |
|---|---|
| ![Cobranza](docs/screenshots/15-cobranza.png) | ![Devolución](docs/screenshots/16-devolucion.png) |

| Fiado vencido |
|---|
| ![Vencimiento](docs/screenshots/17-vencimiento.png) |

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
3. **Cobrar**: elige un método o pulsa **Agregar método** para combinar
   efectivo, Pago Móvil, transferencia, punto de venta y fiado. Si falta cubrir
   el total, pulsa **Dejar resto fiado** y selecciona el cliente.
4. Si usas **Fiado** (total o parcial), crea/selecciona un cliente. La parte
   fiada queda en **Cuentas**.
5. **Cuentas → cliente → Registrar abono**: registra un pago parcial o total.
   Para cobrar todo el saldo de una vez, usa **Saldar cuenta**. Con
   **Enviar cuenta por WhatsApp** le mandas al cliente el saldo y el detalle
   de sus cuentas. **Enviar recordatorio** manda un mensaje corto de cobranza.
6. **Ajustes → Cobranza y datos de pago**: activa el interruptor y carga banco,
   cuenta, titular, cédula/RIF y Pago Móvil. Esos datos se agregan al estado de
   cuenta y al recordatorio. También defines los **días de plazo** de los fiados.
7. **Cuentas → Cobranza**: muestra las cuentas vencidas y por vencer. Toca el
   ícono de WhatsApp para recordarle a un cliente. El inicio avisa cuando hay
   cuentas vencidas.
8. **Cuentas → Nuevo cliente**: puedes fijar un **límite de crédito** en USD.
   Si el cliente lo supera, la app no deja cerrar el fiado. Con el ícono de
   lápiz editas sus datos (nombre, cédula/RIF, teléfono, dirección y límite).
9. **Ventas → venta → Devolver productos**: elige cuántas unidades devuelve el
   cliente de cada producto. Se repone el stock y se ajustan caja y reportes; si
   era fiado, el monto se abona a la cuenta.
10. **Ventas → venta → Anular venta**: devuelve el stock, saca la venta de caja y
    reportes, y anula el fiado. No se permite si la cuenta ya tiene abonos ni si
    la venta tiene devoluciones.
11. **Ventas → venta → Imprimir / compartir nota**: genera el PDF con la leyenda
    “DOCUMENTO NO FISCAL”.
12. **Inicio → Caja**: abre la caja con el fondo inicial, vende y luego ciérrala
    contando el efectivo en Bs y USD. La diferencia queda en el historial.
13. **Inicio → Reportes**: cambia entre Hoy, 7 días, Este mes o un rango
    personalizado. Verás el total vendido, las devoluciones restadas y las
    ventas registradas, con el desglose por método de pago (Punto de venta,
    Efectivo Bs/USD, Pago Móvil, transferencia y fiado), además de los productos
    más vendidos.
14. **Ajustes → Actualizar BCV**: trae la tasa oficial del día. También se
    intenta actualizar sola al abrir la app.
15. **Ajustes → Exportar respaldo**: comparte un archivo `.db` por WhatsApp,
    Drive o correo. **Restaurar respaldo** recupera ese archivo.
16. **Vender → ícono de escanear**: apunta al código de barras y el producto se
    agrega al carrito.
17. **Ajustes → Impresora térmica**: empareja la impresora desde Bluetooth de
    Android, elígela, selecciona 58/80 mm y usa **Imprimir prueba**. Luego, al
    cobrar, aparece **Imprimir ticket**.
18. **Ajustes → Panel remoto**: conecta la tablet con la cuenta del dueño y
    consulta ventas, cuentas, inventario y caja desde el teléfono o la
    computadora. Es de solo lectura: para vender o editar se usa la tablet.

## Qué funciona

- Inventario con stock, stock mínimo, búsqueda y edición.
- Carga rápida de productos: categorías sugeridas, SKU automático, aviso de
  código de barras/SKU duplicado y **Guardar y agregar otro**.
- Lector de código de barras con la cámara desde el POS y desde el producto.
- Ventas con IVA configurable, descuento y doble moneda (USD/Bs).
- Anulación de ventas con devolución de stock y anulación del fiado.
- Devoluciones parciales por producto con reposición de stock y ajuste de caja,
  reportes y cuentas fiadas.
- Cuentas por cobrar con abonos, saldo por cliente, límite de crédito,
  vencimiento de fiados y cobranza con recordatorios por WhatsApp.
- Datos de pago opcionales (banco, cuenta, titular, Pago Móvil y nota) en el
  estado de cuenta y en los recordatorios.
- Cierre de caja con fondo, efectivo esperado, conteo y diferencia.
- Reportes por rango de fechas con totales por método de pago.
- Impresión de ticket en impresora térmica Bluetooth (ESC/POS, 58/80 mm).
- Respaldo y restauración de la base.
- Tasa BCV automática (BCV oficial, con API de respaldo).
- Nota de entrega/recibo en PDF para imprimir o compartir.
- Inicio con ventas del día, cuentas pendientes y stock bajo.
- Panel remoto de solo consulta (ventas, cuentas, inventario y caja) con
  sincronización de cambios a Supabase.
- Los datos quedan guardados en la tablet; la tasa se actualiza cuando hay conexión.

## Limitaciones de esta versión

- Está pensada para **una sola caja/tablet**.
- No emite facturación fiscal (SENIAT); solo documentos no fiscales.
- La app no tiene bloqueo por PIN ni usuarios/roles.
- El panel remoto es de **solo consulta**; para vender o editar se usa la tablet.
- La sincronización entre varias cajas queda para una fase posterior.
- Las devoluciones son por producto; no se puede anular una venta que ya tiene
  devoluciones registradas.
- El lector de barras necesita permiso de cámara; la impresora debe ser
  Bluetooth ESC/POS (no USB ni red por ahora).
- El APK es universal (~72 MB, incluye el lector de códigos); se puede dividir
  por arquitectura para reducir el tamaño.

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
