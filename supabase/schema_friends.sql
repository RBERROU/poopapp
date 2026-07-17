-- Schéma Supabase v3 (amis + envois privés) pour Just Fart.
-- À exécuter APRÈS schema.sql et schema_social.sql (SQL Editor > Run).

-- ---------------------------------------------------------------------------
-- 1. Code ami : identifiant court et partageable pour s'ajouter entre potes.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists friend_code text unique;

-- Rétro-remplit les profils existants.
update public.profiles
  set friend_code = upper(substr(md5(random()::text || id::text), 1, 6))
  where friend_code is null;

-- Nouveau profil : code généré automatiquement.
alter table public.profiles
  alter column friend_code set default upper(substr(md5(random()::text), 1, 6));
alter table public.profiles
  alter column friend_code set not null;

-- ---------------------------------------------------------------------------
-- 2. Amitiés : demande (pending) puis acceptation (accepted).
--    Une ligne par relation, orientée requester -> addressee.
-- ---------------------------------------------------------------------------
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users (id) on delete cascade,
  addressee_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending', -- 'pending' | 'accepted'
  created_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

alter table public.friendships enable row level security;

-- Je vois les relations qui me concernent.
create policy "mes amitiés visibles"
  on public.friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
-- J'envoie une demande en mon nom.
create policy "j'envoie une demande"
  on public.friendships for insert
  with check (auth.uid() = requester_id);
-- J'accepte (ou modifie) une demande qui m'est adressée.
create policy "j'accepte une demande"
  on public.friendships for update
  using (auth.uid() = addressee_id);
-- Chacun des deux peut rompre la relation.
create policy "je retire une amitié"
  on public.friendships for delete
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create index friendships_addressee_idx on public.friendships (addressee_id);
create index friendships_requester_idx on public.friendships (requester_id);

-- Deux personnes sont-elles amies (acceptées, peu importe le sens) ?
create or replace function public.are_friends(a uuid, b uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Envois privés : un pet envoyé à un ami précis.
--    Dénormalisé (name/duration/audio_path) : le destinataire n'a pas accès
--    à la table farts de l'expéditeur, mais l'audio est public dans le bucket.
-- ---------------------------------------------------------------------------
create table public.direct_sends (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  fart_id uuid,
  name text not null,
  duration_ms integer not null,
  audio_path text not null,
  created_at timestamptz not null default now(),
  seen_at timestamptz
);

alter table public.direct_sends enable row level security;

-- Expéditeur et destinataire voient l'envoi.
create policy "mes envois et réceptions visibles"
  on public.direct_sends for select
  using (auth.uid() = sender_id or auth.uid() = recipient_id);
-- J'envoie uniquement à un ami accepté.
create policy "j'envoie à un ami"
  on public.direct_sends for insert
  with check (
    auth.uid() = sender_id
    and public.are_friends(sender_id, recipient_id)
  );
-- Le destinataire marque comme lu.
create policy "je marque mes reçus comme lus"
  on public.direct_sends for update
  using (auth.uid() = recipient_id);

create index direct_sends_recipient_idx
  on public.direct_sends (recipient_id, created_at desc);
