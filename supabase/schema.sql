-- =====================================================================
-- Estadillos de Inventario · esquema de Supabase
-- Pegar entero en Supabase > SQL Editor > New query > Run.
-- Se puede volver a ejecutar sin perder datos.
-- =====================================================================

create extension if not exists postgis;

-- ---------------------------------------------------------------------
-- Usuarios: cada cuenta tiene un perfil con su nombre y su rol.
--   campo   -> rellena fichas de las parcelas que existen
--   oficina -> además crea fincas, carga puntos y borra
-- ---------------------------------------------------------------------
create table if not exists public.perfiles (
  id      uuid primary key references auth.users on delete cascade,
  nombre  text not null default '',
  rol     text not null default 'campo' check (rol in ('campo', 'oficina'))
);

create or replace function public.es_oficina() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfiles where id = auth.uid() and rol = 'oficina');
$$;

-- Altas previstas: el rol (y el nombre) de cada correo antes de crear su cuenta.
create table if not exists public.altas (
  email   text primary key,
  nombre  text,
  rol     text not null default 'campo' check (rol in ('campo', 'oficina'))
);
alter table public.altas enable row level security;  -- solo se gestiona desde el panel de Supabase

-- El perfil se crea solo al dar de alta un usuario en Authentication,
-- con el rol que tenga su correo en "altas" (campo si no está).
create or replace function public.nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare a altas%rowtype;
begin
  select * into a from altas where lower(email) = lower(new.email);
  insert into perfiles (id, nombre, rol)
  values (new.id,
          coalesce(a.nombre, new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1)),
          coalesce(a.rol, 'campo'))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.nuevo_usuario();

-- Equipo de Pradifir
insert into public.altas (email, rol) values
  ('ordenacion@pradifir.com', 'oficina'),
  ('encargado@pradifir.com',  'campo')
on conflict (email) do update set rol = excluded.rol;

-- Si alguna cuenta ya existía, se le aplica su rol ahora.
update public.perfiles p set rol = a.rol, nombre = coalesce(a.nombre, p.nombre)
from public.altas a join auth.users u on lower(u.email) = lower(a.email)
where p.id = u.id;

-- ---------------------------------------------------------------------
-- Fincas y parcelas. La ficha de campo completa va en "ficha" (jsonb);
-- las vistas de abajo la despliegan en tablas para la oficina.
--   updated_at: hora de la tablet en ms; decide qué versión gana.
--   synced_at:  hora del servidor; las tablets bajan lo que sea más nuevo.
-- ---------------------------------------------------------------------
create table if not exists public.fincas (
  id          text primary key,
  nombre      text not null,
  tm          text not null default '',
  radio       numeric not null default 20,
  radio_reg   numeric not null default 5,
  huso        int not null default 30,
  equipo      text not null default '',
  especies    jsonb not null default '[]',
  borrada     boolean not null default false,
  updated_at  bigint not null default 0,
  synced_at   timestamptz not null default now(),
  updated_by  uuid
);

create table if not exists public.parcelas (
  id          text primary key,
  finca_id    text not null references public.fincas (id) on delete cascade,
  num         text not null,
  canton      text not null default '',
  lat         double precision,
  lon         double precision,
  estado      text not null default 'pendiente' check (estado in ('pendiente', 'curso', 'hecha')),
  ficha       jsonb not null default '{}',
  borrada     boolean not null default false,
  updated_at  bigint not null default 0,
  synced_at   timestamptz not null default now(),
  updated_by  uuid
);

-- Posición que puso la oficina, guardada cuando alguien mueve el punto en campo.
alter table public.parcelas add column if not exists lat_orig double precision;
alter table public.parcelas add column if not exists lon_orig double precision;

-- Unidades de vegetación: polígonos de la finca y UV de cada parcela.
--   fincas.uvs: [{id, num, nombre, sup (ha), polys: [{outer: [[lon,lat]...], holes: [...]}],
--                 rodales: [{id, nombre, sup, polys}]}]
--   parcelas.uv: id de la UV donde cae el punto; uv_fija = la oficina la puso a mano.
alter table public.fincas   add column if not exists uvs jsonb not null default '[]';
alter table public.fincas   add column if not exists linde jsonb not null default '[]';  -- polígonos del linde
alter table public.fincas   add column if not exists caminos jsonb not null default '[]'; -- líneas de caminos

-- Parcelas propuestas por la app que la oficina aún no ha aceptado (el campo no las ve).
alter table public.parcelas drop constraint if exists parcelas_estado_check;
alter table public.parcelas add constraint parcelas_estado_check check (estado in ('propuesta', 'pendiente', 'curso', 'hecha'));
alter table public.parcelas add column if not exists uv text;
alter table public.parcelas add column if not exists uv_fija boolean not null default false;
alter table public.parcelas add column if not exists rodal text;   -- rodal de la UV donde cae el punto

create index if not exists parcelas_finca_idx  on public.parcelas (finca_id);
create index if not exists parcelas_synced_idx on public.parcelas (synced_at);
create index if not exists fincas_synced_idx   on public.fincas (synced_at);

-- Si llega una versión más antigua que la guardada, se ignora.
-- El personal de campo puede rellenar la ficha y mover el punto (lat/lon),
-- pero no renumerar, cambiar de finca ni borrar parcelas.
create or replace function public.sello_finca() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then return old; end if;
  new.synced_at  := clock_timestamp();
  new.updated_by := auth.uid();
  return new;
end $$;

create or replace function public.sello_parcela() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at < old.updated_at then return old; end if;
    if not public.es_oficina() then
      new.finca_id := old.finca_id; new.num := old.num; new.canton := old.canton;
      new.borrada := old.borrada;
      -- La posición original de la oficina no se pierde: solo se borra si el punto vuelve a ella.
      if old.lat_orig is not null
         and not (new.lat_orig is null and new.lat = old.lat_orig and new.lon = old.lon_orig) then
        new.lat_orig := old.lat_orig; new.lon_orig := old.lon_orig;
      end if;
    end if;
  end if;
  new.synced_at  := clock_timestamp();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists sello on public.fincas;
create trigger sello before insert or update on public.fincas
  for each row execute function public.sello_finca();
drop trigger if exists sello on public.parcelas;
create trigger sello before insert or update on public.parcelas
  for each row execute function public.sello_parcela();

-- ---------------------------------------------------------------------
-- Permisos (Row Level Security). Nadie sin cuenta ve nada.
-- No hay borrados físicos: se marca "borrada".
-- ---------------------------------------------------------------------
alter table public.perfiles enable row level security;
alter table public.fincas   enable row level security;
alter table public.parcelas enable row level security;

drop policy if exists "ver perfiles" on public.perfiles;
create policy "ver perfiles" on public.perfiles for select to authenticated using (true);
drop policy if exists "oficina edita perfiles" on public.perfiles;
create policy "oficina edita perfiles" on public.perfiles for update to authenticated using (public.es_oficina());

drop policy if exists "ver fincas" on public.fincas;
create policy "ver fincas" on public.fincas for select to authenticated using (true);
drop policy if exists "oficina crea fincas" on public.fincas;
create policy "oficina crea fincas" on public.fincas for insert to authenticated with check (public.es_oficina());
drop policy if exists "oficina edita fincas" on public.fincas;
create policy "oficina edita fincas" on public.fincas for update to authenticated using (public.es_oficina());

drop policy if exists "ver parcelas" on public.parcelas;
create policy "ver parcelas" on public.parcelas for select to authenticated using (true);
drop policy if exists "oficina crea parcelas" on public.parcelas;
create policy "oficina crea parcelas" on public.parcelas for insert to authenticated with check (public.es_oficina());
drop policy if exists "todos rellenan parcelas" on public.parcelas;
create policy "todos rellenan parcelas" on public.parcelas for update to authenticated using (true);

-- ---------------------------------------------------------------------
-- Fotos: carpeta privada "fotos" (finca/parcela/foto.jpg).
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', false)
on conflict (id) do nothing;

drop policy if exists "ver fotos" on storage.objects;
create policy "ver fotos" on storage.objects for select to authenticated using (bucket_id = 'fotos');
drop policy if exists "subir fotos" on storage.objects;
create policy "subir fotos" on storage.objects for insert to authenticated with check (bucket_id = 'fotos');

-- ---------------------------------------------------------------------
-- Vistas para la oficina: tablas listas para Excel, QGIS o ArcGIS.
-- v_parcelas lleva la geometría del punto actual (movido en campo si se movió).
-- ---------------------------------------------------------------------
drop view if exists public.v_parcelas, public.v_pies_mayores, public.v_regenerado, public.v_matorral;

create view public.v_parcelas with (security_invoker = on) as
select
  f.nombre                                   as finca,
  f.tm,
  (select u->>'num' from jsonb_array_elements(f.uvs) u where u->>'id' = p.uv)    as uv_num,
  (select u->>'nombre' from jsonb_array_elements(f.uvs) u where u->>'id' = p.uv) as uv,
  p.rodal,
  p.canton,
  p.num                                      as parcela,
  p.estado,
  p.ficha->>'fecha'                          as fecha,
  p.ficha->>'equipo'                         as equipo,
  p.lat                                      as lat_punto,
  p.lon                                      as lon_punto,
  (p.lat_orig is not null)                   as punto_movido,
  p.lat_orig,
  p.lon_orig,
  case when p.lat_orig is not null then round(st_distance(
    st_setsrid(st_makepoint(p.lon_orig, p.lat_orig), 4326)::geography,
    st_setsrid(st_makepoint(p.lon, p.lat), 4326)::geography)::numeric, 1) end as desplazamiento_m,
  (p.ficha->'gps'->>'lat')::float8           as lat_gps,
  (p.ficha->'gps'->>'lon')::float8           as lon_gps,
  (p.ficha->'gps'->>'acc')::float8           as precision_gps_m,
  p.ficha->>'orient'                         as orientacion,
  f.radio                                    as radio_m,
  jsonb_array_length(coalesce(p.ficha->'pm', '[]'))                                              as n_pies_mayores,
  round((jsonb_array_length(coalesce(p.ficha->'pm', '[]')) / (pi() * f.radio ^ 2 / 10000))::numeric, 1) as pies_ha,
  p.ficha->>'eros'                           as erosion,
  p.ficha->>'defol'                          as defoliacion,
  p.ficha->>'obs'                            as observaciones,
  p.synced_at                                as actualizado,
  st_setsrid(st_makepoint(p.lon, p.lat), 4326) as geom
from public.parcelas p
join public.fincas f on f.id = p.finca_id
where not p.borrada and not f.borrada;

create view public.v_pies_mayores with (security_invoker = on) as
select
  f.nombre as finca, p.canton, p.num as parcela, t.n as num_pie,
  t.x->>'sp'                 as sp,
  (t.x->>'d1')::numeric      as dn1_cm,
  (t.x->>'d2')::numeric      as dn2_cm,
  round(case when t.x->>'d2' is null then (t.x->>'d1')::numeric
             else ((t.x->>'d1')::numeric + (t.x->>'d2')::numeric) / 2 end, 1) as dn_cm,
  (t.x->>'v')::int           as vigor,
  (t.x->>'cm')::int          as copa_muerta
from public.parcelas p
join public.fincas f on f.id = p.finca_id
cross join lateral jsonb_array_elements(coalesce(p.ficha->'pm', '[]')) with ordinality as t(x, n)
where not p.borrada and not f.borrada;

create view public.v_regenerado with (security_invoker = on) as
select f.nombre as finca, p.canton, p.num as parcela,
  r->>'sp' as sp, r->>'tipo' as tipo, (r->>'tot')::int as brotes_totales, (r->>'via')::int as brotes_viables
from public.parcelas p
join public.fincas f on f.id = p.finca_id
cross join lateral jsonb_array_elements(coalesce(p.ficha->'reg', '[]')) as r
where not p.borrada and not f.borrada;

create view public.v_matorral with (security_invoker = on) as
select f.nombre as finca, p.canton, p.num as parcela,
  m->>'sp' as sp, m->>'nombre' as nombre_comun, (m->>'pct')::numeric as pct, (m->>'alt')::numeric as altura_m
from public.parcelas p
join public.fincas f on f.id = p.finca_id
cross join lateral jsonb_array_elements(coalesce(p.ficha->'mat', '[]')) as m
where not p.borrada and not f.borrada;
