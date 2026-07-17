-- Schéma Supabase v1 pour Just Fart.
-- À exécuter dans l'éditeur SQL du dashboard (SQL Editor > New query > Run).
-- Idempotent au premier lancement ; en cas de reprise, supprimer d'abord
-- les objets existants ou ignorer les erreurs "already exists".

-- PostGIS : requêtes géographiques ("pets dans un rayon de X km").
create extension if not exists postgis;

-- ---------------------------------------------------------------------------
-- Profils utilisateurs (un par compte anonyme ; le pseudo est public).
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  pseudo text not null default 'Péteur anonyme',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles lisibles par tous"
  on public.profiles for select using (true);
create policy "chacun crée son profil"
  on public.profiles for insert with check (auth.uid() = id);
create policy "chacun modifie son profil"
  on public.profiles for update using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- Pets : métadonnées ; l'audio vit dans le bucket storage `farts`.
-- L'id vient de l'app (uuid v4 généré localement) pour une synchro simple.
-- ---------------------------------------------------------------------------
create table public.farts (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  duration_ms integer not null,
  created_at timestamptz not null default now(),
  latitude double precision,
  longitude double precision,
  -- Colonne géo dérivée automatiquement, indexable pour "autour de moi".
  location geography (point, 4326) generated always as (
    case
      when longitude is not null and latitude is not null
        then st_setsrid(st_makepoint(longitude, latitude), 4326)::geography
    end
  ) stored,
  audio_path text not null,
  format text not null default 'm4a'
);

create index farts_location_idx on public.farts using gist (location);
create index farts_created_at_idx on public.farts (created_at desc);
create index farts_user_id_idx on public.farts (user_id);

alter table public.farts enable row level security;

create policy "pets lisibles par tous"
  on public.farts for select using (true);
create policy "chacun poste ses pets"
  on public.farts for insert with check (auth.uid() = user_id);
create policy "chacun modifie ses pets"
  on public.farts for update using (auth.uid() = user_id);
create policy "chacun supprime ses pets"
  on public.farts for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Bucket audio : lecture publique, chacun écrit uniquement dans son dossier
-- ({user_id}/{fart_id}.ext).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('farts', 'farts', true);

create policy "audio lisible par tous"
  on storage.objects for select
  using (bucket_id = 'farts');
create policy "upload dans son dossier"
  on storage.objects for insert
  with check (
    bucket_id = 'farts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "mise à jour dans son dossier"
  on storage.objects for update
  using (
    bucket_id = 'farts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "suppression dans son dossier"
  on storage.objects for delete
  using (
    bucket_id = 'farts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
