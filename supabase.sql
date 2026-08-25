-- ============================================================
-- FERRO — Taula de dades al núvol
-- Executa aquest SQL al teu projecte Supabase:
--   Dashboard > SQL Editor > New query > Executa tot
-- ============================================================

create table if not exists public.user_data (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Seguretat a nivell de fila: cada usuari només veu i edita les seues dades
alter table public.user_data enable row level security;

drop policy if exists "lectura propia" on public.user_data;
create policy "lectura propia"
  on public.user_data for select
  using (auth.uid() = user_id);

drop policy if exists "insercio propia" on public.user_data;
create policy "insercio propia"
  on public.user_data for insert
  with check (auth.uid() = user_id);

drop policy if exists "actualitzacio propia" on public.user_data;
create policy "actualitzacio propia"
  on public.user_data for update
  using (auth.uid() = user_id);

-- ============================================================
-- FERRO — Amics i xat
-- ============================================================

-- Perfils públics (per buscar amics per email)
create table if not exists public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  email        text not null unique,
  display_name text,
  alias        text unique,   -- nom mostrat als amics (únic a tota l'app)
  created_at   timestamptz not null default now()
);

-- Per a projectes que ja tenen la taula creada (afegeix la columna si falta)
alter table public.profiles add column if not exists alias text;
-- Avatar configurat per l'usuari (string "color|simbol|marc"), per mostrar-lo als amics
alter table public.profiles add column if not exists avatar text;
-- Índex únic per a l'alias (si encara no existeix)
do $$
begin
  if not exists (select 1 from pg_indexes where tablename='profiles' and indexname='profiles_alias_key') then
    alter table public.profiles add constraint profiles_alias_key unique (alias);
  end if;
end $$;

alter table public.profiles enable row level security;

drop policy if exists "perfils: llegir" on public.profiles;
create policy "perfils: llegir"
  on public.profiles for select
  using (auth.role() = 'authenticated');

drop policy if exists "perfils: crear propi" on public.profiles;
create policy "perfils: crear propi"
  on public.profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "perfils: actualitzar propi" on public.profiles;
create policy "perfils: actualitzar propi"
  on public.profiles for update
  using (auth.uid() = user_id);

-- ============================================================
-- FERRO — Dades esportives de cada usuari (onboarding)
-- ============================================================
-- Guarda les dades que la persona registra a la finestra d'onboarding:
-- alias (redundant amb profiles.alias, per comoditat), altura, pes, edat,
-- dies d'entrenament preferits a la setmana, freqüència d'esport i sexe.
create table if not exists public.user_sports_data (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  alias         text,
  altura_cm     numeric,
  pes_kg        numeric,
  edat          integer,
  dies_setmana  integer,
  frequencia    text check (frequencia in ('asidua','puntual','cap')),
  sexe          text check (sexe in ('home','dona','altre')),
  updated_at    timestamptz not null default now()
);

alter table public.user_sports_data enable row level security;

drop policy if exists "dades esportives: llegir" on public.user_sports_data;
create policy "dades esportives: llegir"
  on public.user_sports_data for select
  using (auth.uid() = user_id);

drop policy if exists "dades esportives: crear propi" on public.user_sports_data;
create policy "dades esportives: crear propi"
  on public.user_sports_data for insert
  with check (auth.uid() = user_id);

drop policy if exists "dades esportives: actualitzar propi" on public.user_sports_data;
create policy "dades esportives: actualitzar propi"
  on public.user_sports_data for update
  using (auth.uid() = user_id);

-- Comprova si un alias ja està en ús per un altre usuari (per a la unicitat).
create or replace function public.alias_taken(p_alias text, p_user_id uuid default null)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where lower(alias) = lower(p_alias)
      and (p_user_id is null or user_id <> p_user_id)
  );
$$;

revoke execute on function public.alias_taken(text, uuid) from public, anon;
grant execute on function public.alias_taken(text, uuid) to authenticated;

-- Amics (sol·licituds + acceptacions)
create table if not exists public.friends (
  user_id    uuid not null references auth.users (id) on delete cascade,
  friend_id  uuid not null references auth.users (id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

alter table public.friends enable row level security;

drop policy if exists "amics: enviar sol·licitud" on public.friends;
create policy "amics: enviar sol·licitud"
  on public.friends for insert
  with check (auth.uid() = user_id);

drop policy if exists "amics: veure" on public.friends;
create policy "amics: veure"
  on public.friends for select
  using (auth.uid() = user_id or auth.uid() = friend_id);

drop policy if exists "amics: acceptar" on public.friends;
create policy "amics: acceptar"
  on public.friends for update
  using (auth.uid() = friend_id);

drop policy if exists "amics: eliminar" on public.friends;
create policy "amics: eliminar"
  on public.friends for delete
  using (auth.uid() = user_id or auth.uid() = friend_id);

-- Xat entre amics
create extension if not exists pgcrypto;

create table if not exists public.chat_messages (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  message      text not null,
  created_at   timestamptz not null default now()
);

alter table public.chat_messages enable row level security;

drop policy if exists "xat: enviar" on public.chat_messages;
create policy "xat: enviar"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.friends f
      where f.status = 'accepted'
        and ((f.user_id = auth.uid() and f.friend_id = recipient_id)
          or (f.friend_id = auth.uid() and f.user_id = recipient_id))
    )
  );

drop policy if exists "xat: llegir" on public.chat_messages;
create policy "xat: llegir"
  on public.chat_messages for select
  using (auth.uid() = sender_id or auth.uid() = recipient_id);

-- Permetre llegir les dades dels amics (per comparar medalles)
drop policy if exists "lectura d'amics" on public.user_data;
create policy "lectura d'amics"
  on public.user_data for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.friends f
      where f.status = 'accepted'
        and ((f.user_id = auth.uid() and f.friend_id = user_data.user_id)
          or (f.friend_id = auth.uid() and f.user_id = user_data.user_id))
    )
  );

-- ============================================================
-- FERRO — Codis d'invitació
-- ============================================================

-- Cada usuari té un codi numèric (5 xifres, comença amb un número de 3)
-- que pot compartir perquè altres l'afegisquen com a amic.
-- La taula guarda internament els codis ja usats; en donar de baixa
-- el compte, la clau forana esborra el codi i queda lliure per a reutilitzar.
create table if not exists public.friend_codes (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  code       text not null unique,
  created_at timestamptz not null default now()
);

alter table public.friend_codes enable row level security;

-- Qualsevol usuari amb sessió pot buscar per codi per a trobar l'altre usuari
drop policy if exists "codis: llegir" on public.friend_codes;
create policy "codis: llegir"
  on public.friend_codes for select
  using (auth.role() = 'authenticated');

-- Només pots crear/actualitzar el teu propi codi
drop policy if exists "codis: crear propi" on public.friend_codes;
create policy "codis: crear propi"
  on public.friend_codes for insert
  with check (auth.uid() = user_id);

drop policy if exists "codis: actualitzar propi" on public.friend_codes;
create policy "codis: actualitzar propi"
  on public.friend_codes for update
  using (auth.uid() = user_id);

-- ============================================================
-- FERRO — Baixa del compte (esborra totes les dades)
-- ============================================================

-- Esborra l'usuari d'`auth.users`. Les claus foranes amb ON DELETE CASCADE
-- s'encarreguen d'esborrar user_data, profiles, friends, chat_messages i
-- friend_codes (alliberant el codi d'invitació).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
begin
  if _uid is null then
    raise exception 'Usuari no autenticat';
  end if;
  delete from auth.users where id = _uid;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;