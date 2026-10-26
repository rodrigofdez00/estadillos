# Estadillos de Inventario: puesta en marcha

App para rellenar los estadillos de inventario en la tablet, sin papel y sin necesidad de cobertura,
y consultar los datos desde la oficina.

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app (tablet de campo y ordenador de oficina) |
| `config.js` | Dirección y clave de Supabase (lo único que hay que rellenar) |
| `sw.js`, `manifest.webmanifest`, `icon.svg` | Para que se instale en la tablet y funcione sin cobertura |
| `supabase/schema.sql` | Tablas, permisos y vistas de la base de datos |

## Antes de nada: las tablets necesitan GPS

Muchas tablets **solo Wi-Fi** (por ejemplo, los iPad Wi-Fi y bastantes Android baratos) **no tienen GPS**.
Sin GPS la app no puede guiar hasta el punto, tomar coordenadas ni mover puntos.
Comprueba que las tablets tienen GPS/GNSS; suelen tenerlo los modelos con **4G/LTE**, aunque no lleven tarjeta SIM.

## 1. Crear la base de datos (una vez, 10 minutos)

1. Crea una cuenta en <https://supabase.com> y un proyecto nuevo. Región: **West EU (Ireland)** o **Central EU (Frankfurt)**.
2. Ve a **SQL Editor → New query**, pega todo `supabase/schema.sql` y pulsa **Run**. Se puede volver a ejecutar sin perder datos cuando haya cambios.
3. Ve a **Authentication → Sign In / Providers** y **desactiva «Allow new users to sign up»**. Así solo entra quien dé de alta la oficina.
4. Ve a **Project Settings → API** y copia la **Project URL** y la clave **anon public** en `config.js`.

## 2. Dar de alta al equipo

1. Abre **Authentication → Users → Add user → Create new user**, escribe el correo y una contraseña y marca *Auto Confirm User*.
2. Todos entran con rol **campo**. A quien vaya a trabajar desde la oficina cámbiale el rol: **Table Editor → perfiles**, columna `rol` = `oficina`. Ahí también puedes poner el `nombre` que se mostrará en la app.

| Rol | Puede |
|---|---|
| campo | Ver las fincas, rellenar las fichas y **mover el punto** de una parcela a donde se mide |
| oficina | Además, crear fincas, cargar los puntos (KMZ/KML/CSV), renumerar, borrar y ver la tabla resumen |

## 3. Dónde está publicada

- **App:** <https://rodrigofdez00.github.io/estadillos/>
- **Código:** <https://github.com/rodrigofdez00/estadillos> (GitHub Pages publica la rama `main`)
- **Base de datos:** proyecto de Supabase `bgxqwhfdvjleklwatrjq` (Europa Oeste)

Cada cambio que se sube a `main` se publica solo en uno o dos minutos. Las tablets reciben la versión nueva la siguiente vez que abren la app con conexión.

## 4. En cada tablet

1. Abre <https://rodrigofdez00.github.io/estadillos/> con **Chrome** (Android) o **Safari** (iPad) y entra con tu correo y contraseña.
2. Instálala: en Chrome, menú ⋮ → **Añadir a pantalla de inicio**; en Safari, botón Compartir → **Añadir a pantalla de inicio**.
3. Acepta el permiso de **ubicación**.
4. Abre la app una vez con cobertura antes de ir al campo. A partir de ahí funciona sin conexión: las fichas se guardan en la tablet y se suben solas cuando hay red (o al conectarse al Wi-Fi de la oficina). En la cabecera se ve el estado (verde: todo subido; naranja: cambios pendientes).

La app se usa en vertical y en horizontal. En tablet, la ficha se reparte en dos columnas: en «Pies mayores», la entrada de datos queda fija a la izquierda y la lista de pies a la derecha.

## 5. Flujo de trabajo

1. **Oficina:** crea la finca (nombre, término, radio de parcela y de regenerado, huso UTM) y carga los puntos desde **Ajustes → Importar puntos**. Vale el KMZ que exporta el SIG (el nombre de cada punto es el nº de parcela) o un CSV `parcela;lat;lon` o `parcela;x;y`.
   Después carga las **unidades de vegetación y rodales** en **Ajustes → Importar UV y rodales**, con la capa de rodales del SIG (campos `UV_id`, `UV`, `Rodal` y `Sup`), y el **linde** en **Importar linde**.
   - Vale el **shapefile**: elige a la vez el `.shp`, el `.dbf` y el `.prj`, o un `.zip` con ellos. La proyección se lee del `.prj` (UTM ETRS89 de cualquier huso). También valen KML/KMZ.
   - Los polígonos con el mismo identificador forman una UV y, dentro de ella, cada rodal.
   - La superficie se toma del campo `Sup` si existe; si no, se calcula.
   - Cada parcela se asigna a la UV en la que cae su punto, y se recalcula si se mueve en campo.
   - El nº, el nombre y la superficie de cada UV se pueden corregir. También se puede fijar a mano la UV de una parcela.
   **Proponer las parcelas (opcional).** Carga también los **caminos** en Ajustes (`Importar caminos`, shape de líneas). En la finca, la sección **Proponer parcelas de inventario** calcula los puntos con estas reglas, que se pueden cambiar:
   - Solo en las UV **arboladas**. La app lo deduce del nombre (matorral, pastizal, cultivo, olivar, infraestructuras… no se inventarían) y se cambia con la casilla **Arbolada** de cada UV en Ajustes.
   - Número de parcelas: 1 por cada 10 ha de cada UV, redondeando hacia arriba, con un mínimo por UV. Se reparten entre los rodales según su superficie y separadas entre sí.
   - Accesibles: a 100 m como máximo de un camino y a 25 m como mínimo, para que el camino no cruce la parcela.
   - El círculo de la parcela queda entero dentro de la UV, con una pendiente de como máximo el 50 % en todo él. La pendiente se calcula con el MDT de 5 m del IGN.
   - Representativas y con un número de pies parecido: la cobertura de copas, medida en la ortofoto PNOA, debe ser cercana a la típica de la UV (su mediana), en un entorno homogéneo.

   Las propuestas salen en morado en el mapa, con su círculo. Cada una muestra su cobertura, su pendiente, la distancia al camino y los avisos. Se pueden **aceptar** (pasan a ser parcelas y las ve el campo), **arrastrar** en el mapa (se recalculan sus datos) o **descartar**. El botón **Ver pendiente** pinta en amarillo las zonas del 30 al 50 % y en rojo las de más del 50 %.

2. **Campo:** abre la finca. El mapa muestra la ortofoto PNOA del IGN (o el mapa base) con las UV, los rodales, el linde, las parcelas y tu posición. El botón ⛶ de la esquina lo pone en pantalla completa (y lo quita); ◎ centra el mapa en tu posición.
   - Antes de salir al campo, con conexión, pulsa **Guardar mapa sin cobertura**: descarga la ortofoto de la finca a la tablet. Para Domingo son unas 960 teselas, menos de medio minuto.
   - Toca una parcela en el mapa o en la lista y sigue la flecha hasta el punto.
   - Si el punto cae en un sitio no representativo (camino, roquedo, charca…), ponte donde vas a medir y pulsa **Datos → Mover el punto aquí**. La posición de la oficina se guarda y se puede recuperar con **Volver al original**.
   - Rellena las pestañas y pulsa **Terminar**.
3. **Oficina:** ve el avance en la tabla resumen de la finca y exporta:
   - **Excel de análisis por UV** (un archivo por UV, `UV1_ENCINAR_DENSO_analisis.xlsx`…), igual que el modelo de la oficina: hojas Pies Mayores, Parcelas, Regenerado estrato arbóreo, Matorral, Error y Notas de campo (extra), con sus fórmulas y gráficos.
     - Entran las parcelas de la UV con la ficha empezada o terminada.
     - Si hay más de una especie, se añade un bloque por especie (DNm, nº de pies, clases diamétricas, vigor y copa muerta, con sus gráficos).
     - Comprobado con los datos de `UV1_ENCINAR_analisis_12.xlsx`: mismos resultados.
   - **Datos completos**: un Excel con todo lo recogido, incluidos los árboles tipo, las coordenadas y los puntos movidos.
   - **KML de puntos**, para abrirlo en QGIS, ArcGIS o Google Earth:
     - Carpeta *Parcelas de Inventario*: cada parcela en su posición actual (la movida, si se movió), coloreada por estado. Las movidas van en naranja.
     - Carpeta *Posiciones originales*: el punto que puso la oficina y una línea hasta el nuevo, solo para las parcelas movidas.
     - Cada punto lleva sus datos: Parcela, Canton, Estado, Movida, Desplaz_m, Lat_orig, Lon_orig, Fecha, Equipo, Pies_may y Pies_ha.
     - Si se vuelve a importar este KML en la app, se ignoran las posiciones originales.
   - **Fotos** de la finca.

Si la oficina vuelve a importar el KMZ original, las parcelas movidas en campo conservan su posición nueva.

### Datos directos para SIG

En la base de datos hay vistas ya preparadas:

- `v_parcelas`: geometría del punto actual (EPSG:4326), `punto_movido`, `lat_orig`, `lon_orig` y `desplazamiento_m`.
- `v_pies_mayores`, `v_regenerado` y `v_matorral`.

Se abren en **QGIS** como capa PostGIS con los datos de **Project Settings → Database**, o se exportan a CSV desde **Table Editor**.

Por seguridad, conecta QGIS con un usuario de base de datos de solo lectura. Si lo necesitas, te preparo la orden para crearlo.

## Notas

- Si dos personas editan la misma parcela, gana la última versión guardada.
- Las fotos se reducen en la tablet a unos 300 KB y se guardan en Supabase Storage (carpeta `fotos`). El plan gratuito de Supabase incluye 1 GB.
- Si una tablet pasa días sin cobertura, **Exportar copia** en la pantalla de inicio guarda todas sus fichas en un archivo. Al importarlo en otro dispositivo se conserva la versión más reciente de cada parcela.
