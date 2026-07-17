-- Schéma Supabase v2 (phase sociale) pour Just Fart.
-- À exécuter APRÈS schema.sql, dans le SQL Editor (New query > Run).
-- Ajoute : réactions emoji, signalement, blocage, et une vue "feed public"
-- où la position est FLOUTÉE (arrondie au ~quartier) pour protéger la vie privée.

-- ---------------------------------------------------------------------------
-- 1. Vie privée : la table farts n'est plus lisible publiquement en entier.
--    Le propriétaire lit ses pets exacts ; tout le monde lit le feed via la
--    vue public_feed (position arrondie, colonnes sensibles masquées).
-- ---------------------------------------------------------------------------
drop policy if exists "pets lisibles par tous" on public.farts;

create policy "chacun lit ses propres pets"
  on public.farts for select using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 2. Réactions emoji : une par (pet, utilisateur, emoji).
-- ---------------------------------------------------------------------------
create table public.reactions (
  fart_id uuid not null references public.farts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (fart_id, user_id, emoji)
);

alter table public.reactions enable row level security;

create policy "réactions lisibles par tous"
  on public.reactions for select using (true);
create policy "chacun réagit pour lui"
  on public.reactions for insert with check (auth.uid() = user_id);
create policy "chacun retire sa réaction"
  on public.reactions for delete using (auth.uid() = user_id);

create index reactions_fart_idx on public.reactions (fart_id);

-- ---------------------------------------------------------------------------
-- 3. Signalements (modération) : un utilisateur signale un pet.
--    Personne ne peut lire les signalements côté client (traitement admin).
-- ---------------------------------------------------------------------------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  fart_id uuid not null references public.farts (id) on delete cascade,
  reason text,
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "chacun signale"
  on public.reports for insert with check (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------------
-- 4. Blocages : masque tous les pets d'un utilisateur dans mon feed.
-- ---------------------------------------------------------------------------
create table public.blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table public.blocks enable row level security;

create policy "je gère mes blocages (lecture)"
  on public.blocks for select using (auth.uid() = blocker_id);
create policy "je bloque"
  on public.blocks for insert with check (auth.uid() = blocker_id);
create policy "je débloque"
  on public.blocks for delete using (auth.uid() = blocker_id);

-- ---------------------------------------------------------------------------
-- 5. Vue du feed public : position FLOUTÉE, pseudo, compteurs de réactions,
--    exclusion des utilisateurs bloqués et de mes propres pets.
--    security_invoker=false : la vue lit les tables de base en contournant
--    la RLS, mais n'expose QUE des colonnes sûres (jamais la position exacte).
-- ---------------------------------------------------------------------------
create or replace view public.public_feed
with (security_invoker = false) as
select
  f.id,
  f.user_id,
  coalesce(p.pseudo, 'Péteur anonyme') as pseudo,
  f.name,
  f.duration_ms,
  f.created_at,
  -- Floutage : arrondi à 2 décimales (~1,1 km), jamais la position exacte.
  round(f.latitude::numeric, 2)::float8 as lat_fuzzy,
  round(f.longitude::numeric, 2)::float8 as lng_fuzzy,
  (f.latitude is not null and f.longitude is not null) as has_location,
  f.audio_path,
  f.format,
  coalesce(r.counts, '{}'::jsonb) as reactions,
  coalesce(r.total, 0) as reaction_total
from public.farts f
left join public.profiles p on p.id = f.user_id
left join lateral (
  select
    jsonb_object_agg(emoji, cnt) as counts,
    sum(cnt) as total
  from (
    select emoji, count(*)::int as cnt
    from public.reactions
    where fart_id = f.id
    group by emoji
  ) s
) r on true
where f.user_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000')
  and f.user_id not in (
    select blocked_id from public.blocks where blocker_id = auth.uid()
  );

grant select on public.public_feed to anon, authenticated;
