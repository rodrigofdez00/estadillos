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

## 3. Publicar la app

La tablet solo da el GPS a páginas con **https**, así que la carpeta tiene que estar en un alojamiento web. Opciones gratuitas:

- **Netlify:** crea una cuenta, entra en <https://app.netlify.com/drop> y arrastra esta carpeta `estadillos`. Te da una dirección del tipo `https://estadillos-xxxx.netlify.app`.
- **GitHub Pages** o **Cloudflare Pages**, si ya usáis alguno.

Cada vez que cambie la app, se vuelve a subir la carpeta y las tablets se actualizan solas la siguiente vez que abran la app con conexión.

## 4. En cada tablet

1. Abre la dirección con **Chrome** (Android) o **Safari** (iPad) y entra con tu correo y contraseña.
2. Instálala: en Chrome, menú ⋮ → **Añadir a pantalla de inicio**; en Safari, botón Compartir → **Añadir a pantalla de inicio**.
3. Acepta el permiso de **ubicación**.
4. Abre la app una vez con cobertura antes de ir al campo. A partir de ahí funciona sin conexión: las fichas se guardan en la tablet y se suben solas cuando hay red (o al conectarse al Wi-Fi de la oficina). En la cabecera se ve el estado (verde: todo subido; naranja: cambios pendientes).

La app se usa en vertical y en horizontal. En tablet, la ficha se reparte en dos columnas: en «Pies mayores», la entrada de datos queda fija a la izquierda y la lista de pies a la derecha.

## 5. Flujo de trabajo

1. **Oficina:** crea la finca (nombre, término, radio de parcela y de regenerado, huso UTM) y carga los puntos desde **Ajustes → Importar puntos**. Vale el KMZ que exporta el SIG (el nombre de cada punto es el nº de parcela) o un CSV `parcela;lat;lon` o `parcela;x;y`.
2. **Campo:** abre la finca, elige la parcela y sigue la flecha hasta el punto.
   - Si el punto cae en un sitio no representativo (camino, roquedo, charca…), ponte donde vas a medir y pulsa **Datos → Mover el punto aquí**. La posición de la oficina se guarda y se puede recuperar con **Volver al original**.
   - Rellena las pestañas y pulsa **Terminar**.
3. **Oficina:** ve el avance en la tabla resumen de la finca y exporta:
   - **Excel**, con las hojas Parcelas, Pies Mayores, Árboles tipo, Pies menores, Regenerado, Estrato inferior, Matorral y Notas de campo. En la hoja Parcelas salen la posición del punto, si se movió, la posición original y cuántos metros se desplazó.
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
