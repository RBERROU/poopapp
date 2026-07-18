-- =====================================================================
-- Just Fart — Schéma v2 « communautaire » (conversations privées).
-- REMPLACE tout l'ancien schéma public. À exécuter dans le SQL Editor.
-- ⚠️ DESTRUCTIF : supprime les tables existantes (données de test).
-- =====================================================================

-- --- Reset de l'ancien modèle public ---------------------------------
drop view  if exists public.public_feed cascade;
drop table if exists public.direct_sends cascade;
drop table if exists public.reactions cascade;
drop table if exists public.reports cascade;
drop table if exists public.blocks cascade;
drop table if exists public.friendships cascade;
drop table if exists public.farts cascade;
drop table if exists public.profiles cascade;
drop function if exists public.are_friends(uuid, uuid) cascade;

-- =====================================================================
-- Profils
-- =====================================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  pseudo text not null default 'Péteur anonyme',
  friend_code text unique not null
    default upper(substr(md5(random()::text), 1, 6)),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- Les pseudos sont visibles (on affiche ceux de ses potes/membres).
create policy "profils lisibles" on public.profiles for select using (true);
create policy "je crée mon profil" on public.profiles for insert
  with check (auth.uid() = id);
create policy "je modifie mon profil" on public.profiles for update
  using (auth.uid() = id);

-- =====================================================================
-- Amitiés (demande -> acceptation)
-- =====================================================================
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users (id) on delete cascade,
  addressee_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);
alter table public.friendships enable row level security;

create policy "mes amitiés visibles" on public.friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "j'envoie une demande" on public.friendships for insert
  with check (auth.uid() = requester_id);
create policy "j'accepte une demande" on public.friendships for update
  using (auth.uid() = addressee_id);
create policy "je retire une amitié" on public.friendships for delete
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create function public.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a))
  );
$$;

-- =====================================================================
-- Pets perso (backup cloud de la collection) — PRIVÉ au propriétaire.
-- L'audio vit dans le bucket public ; c'est en partageant dans une
-- conversation que d'autres peuvent le lire (métadonnées recopiées dans posts).
-- =====================================================================
create table public.farts (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  duration_ms integer not null,
  created_at timestamptz not null default now(),
  latitude double precision,
  longitude double precision,
  audio_path text not null,
  format text not null default 'm4a'
);
alter table public.farts enable row level security;

create policy "je lis mes pets" on public.farts for select
  using (auth.uid() = user_id);
create policy "je crée mes pets" on public.farts for insert
  with check (auth.uid() = user_id);
create policy "je modifie mes pets" on public.farts for update
  using (auth.uid() = user_id);
create policy "je supprime mes pets" on public.farts for delete
  using (auth.uid() = user_id);

-- =====================================================================
-- Conversations (fil privé à 2, ou groupe) + membres
-- =====================================================================
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'group',   -- 'direct' | 'group'
  name text,                             -- null pour un direct
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.conversations enable row level security;

create table public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);
alter table public.conversation_members enable row level security;

-- Fonction SECURITY DEFINER : évite la récursion RLS quand une policy de
-- conversation_members doit vérifier l'appartenance à la même table.
create function public.is_member(conv uuid, uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversation_members m
    where m.conversation_id = conv and m.user_id = uid
  );
$$;

-- Conversations : visibles/éditables par leurs membres.
create policy "je vois mes conversations" on public.conversations for select
  using (public.is_member(id, auth.uid()));
create policy "je crée une conversation" on public.conversations for insert
  with check (auth.uid() = created_by);

-- Membres : un membre voit la liste ; on s'ajoute soi (création) ou on ajoute
-- un ami dans une conversation dont on est membre.
create policy "je vois les membres" on public.conversation_members for select
  using (public.is_member(conversation_id, auth.uid()));
create policy "j'ajoute des membres" on public.conversation_members for insert
  with check (
    user_id = auth.uid()  -- je me joins (à la création)
    or (
      public.is_member(conversation_id, auth.uid())
      and public.are_friends(auth.uid(), user_id)
    )
  );
create policy "je quitte une conversation" on public.conversation_members for delete
  using (user_id = auth.uid());

create index conv_members_user_idx on public.conversation_members (user_id);

-- =====================================================================
-- Posts (un pet partagé dans une conversation) + réactions
-- =====================================================================
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  fart_id uuid,
  name text not null,
  duration_ms integer not null,
  audio_path text not null,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);
alter table public.posts enable row level security;

create policy "je lis les posts de mes conversations" on public.posts for select
  using (public.is_member(conversation_id, auth.uid()));
create policy "je poste dans mes conversations" on public.posts for insert
  with check (
    sender_id = auth.uid()
    and public.is_member(conversation_id, auth.uid())
  );

create index posts_conv_idx on public.posts (conversation_id, created_at desc);

create table public.post_reactions (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, emoji)
);
alter table public.post_reactions enable row level security;

create policy "je vois les réactions de mes conversations"
  on public.post_reactions for select
  using (exists (
    select 1 from public.posts p
    where p.id = post_id and public.is_member(p.conversation_id, auth.uid())
  ));
create policy "je réagis" on public.post_reactions for insert
  with check (user_id = auth.uid());
create policy "je retire ma réaction" on public.post_reactions for delete
  using (user_id = auth.uid());

-- =====================================================================
-- RPC : ouvrir (ou créer) le fil direct entre moi et un ami.
-- Garantit un seul direct par paire.
-- =====================================================================
create function public.get_or_create_direct(other uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  conv uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if not public.are_friends(me, other) then
    raise exception 'not friends';
  end if;

  -- Cherche un direct existant réunissant exactement ces deux-là.
  select c.id into conv
  from public.conversations c
  where c.kind = 'direct'
    and public.is_member(c.id, me)
    and public.is_member(c.id, other)
  limit 1;

  if conv is not null then return conv; end if;

  insert into public.conversations (kind, created_by)
    values ('direct', me) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id)
    values (conv, me), (conv, other);
  return conv;
end;
$$;

-- Mes conversations, avec titre, dernier pet et nombre de non-lus (1 appel).
create function public.my_conversations()
returns table (
  id uuid,
  kind text,
  title text,
  last_post_name text,
  last_sender_pseudo text,
  last_at timestamptz,
  unread integer,
  member_count integer
) language sql stable security definer set search_path = public as $$
  select
    c.id,
    c.kind,
    case when c.kind = 'group' then coalesce(c.name, 'Groupe')
      else coalesce((
        select pr.pseudo from public.conversation_members m2
        join public.profiles pr on pr.id = m2.user_id
        where m2.conversation_id = c.id and m2.user_id <> auth.uid()
        limit 1), 'Pote') end as title,
    lp.name as last_post_name,
    lp.pseudo as last_sender_pseudo,
    lp.created_at as last_at,
    coalesce((
      select count(*) from public.posts p
      where p.conversation_id = c.id
        and p.sender_id <> auth.uid()
        and p.created_at > coalesce(cm.last_read_at, 'epoch'::timestamptz)
    ), 0)::int as unread,
    (select count(*) from public.conversation_members m
      where m.conversation_id = c.id)::int as member_count
  from public.conversation_members cm
  join public.conversations c on c.id = cm.conversation_id
  left join lateral (
    select p.name, p.created_at, pr.pseudo
    from public.posts p
    join public.profiles pr on pr.id = p.sender_id
    where p.conversation_id = c.id
    order by p.created_at desc limit 1
  ) lp on true
  where cm.user_id = auth.uid()
  order by coalesce(lp.created_at, c.created_at) desc;
$$;
