-- Votación comunitaria del Manual del Guardián
-- Ejecuta este archivo completo en Supabase > SQL Editor.
-- Cada navegador puede votar por hasta cuatro personajes distintos.
-- El identificador es anónimo y no verifica una identidad humana.
-- La página usa solo la clave publicable, nunca la service_role.

begin;

create table if not exists public.community_characters (
  id text primary key
);

create table if not exists public.community_character_votes (
  voter_hash text not null check (voter_hash ~ '^[0-9a-f]{64}$'),
  character_id text not null references public.community_characters(id) on update cascade on delete restrict,
  updated_at timestamptz not null default now(),
  primary key (voter_hash, character_id)
);

-- Migra la versión anterior, que permitía un solo voto por navegador.
do $migration$
declare
  old_primary_key text;
begin
  select constraint_row.conname into old_primary_key
  from pg_catalog.pg_constraint as constraint_row
  where constraint_row.conrelid = 'public.community_character_votes'::regclass
    and constraint_row.contype = 'p';

  if old_primary_key is not null then
    execute format('alter table public.community_character_votes drop constraint %I', old_primary_key);
  end if;

  alter table public.community_character_votes
    add constraint community_character_votes_pkey primary key (voter_hash, character_id);
end;
$migration$;

alter table public.community_characters enable row level security;
alter table public.community_character_votes enable row level security;
revoke all on table public.community_characters from public, anon, authenticated;
revoke all on table public.community_character_votes from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

insert into public.community_characters (id) values
  ('24'), ('agrippa'), ('aigis'), ('alva'), ('arachne'), ('caecus'),
  ('caraboo'), ('castor'), ('corposant'), ('daffodil'), ('doll'),
  ('doll-infierno'), ('doresain'), ('erica'), ('faint'), ('faros'),
  ('goliat'), ('hameln'), ('helot'), ('helot-catena'), ('horla'), ('karen'),
  ('kathigu-ra'), ('lily'), ('lotan'), ('lotan-cetarchon'), ('mouchette'),
  ('murphy-fauxborn'), ('nautila'), ('nymphaea'), ('ogier'), ('ogier-oathbound'),
  ('pandia'), ('pickman'), ('pollux'), ('ramona'), ('ramona-bucle'), ('ryker'),
  ('salvador'), ('saya'), ('sorel'), ('tawil'), ('thais'), ('uvhash'),
  ('vivian'), ('vortice'), ('xu')
on conflict (id) do nothing;

create or replace function public.get_community_character_vote_counts()
returns table(character_id text, votes bigint)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select characters.id, count(votes.voter_hash)::bigint
  from public.community_characters as characters
  left join public.community_character_votes as votes on votes.character_id = characters.id
  group by characters.id
  order by characters.id;
$function$;

drop function if exists public.get_community_character_my_vote(text);
drop function if exists public.set_community_character_vote(text, text);

create or replace function public.get_community_character_my_votes(p_voter_hash text)
returns table(character_id text)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select votes.character_id
  from public.community_character_votes as votes
  where votes.voter_hash = p_voter_hash
    and p_voter_hash ~ '^[0-9a-f]{64}$'
  order by votes.updated_at, votes.character_id;
$function$;

create or replace function public.toggle_community_character_vote(p_voter_hash text, p_character_id text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  current_vote_count integer;
begin
  if p_voter_hash is null or p_voter_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid voter identifier';
  end if;

  if not exists (
    select 1 from public.community_characters where id = p_character_id
  ) then
    raise exception 'Unknown character';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_voter_hash, 0));

  if exists (
    select 1 from public.community_character_votes
    where voter_hash = p_voter_hash and character_id = p_character_id
  ) then
    delete from public.community_character_votes
    where voter_hash = p_voter_hash and character_id = p_character_id;
    return false;
  end if;

  select count(*)::integer into current_vote_count
  from public.community_character_votes
  where voter_hash = p_voter_hash;

  if current_vote_count >= 4 then
    raise exception 'Maximum of four votes reached';
  end if;

  insert into public.community_character_votes (voter_hash, character_id)
  values (p_voter_hash, p_character_id);
  return true;
end;
$function$;

revoke all on function public.get_community_character_vote_counts() from public, anon, authenticated;
revoke all on function public.get_community_character_my_votes(text) from public, anon, authenticated;
revoke all on function public.toggle_community_character_vote(text, text) from public, anon, authenticated;
grant execute on function public.get_community_character_vote_counts() to anon, authenticated;
grant execute on function public.get_community_character_my_votes(text) to anon, authenticated;
grant execute on function public.toggle_community_character_vote(text, text) to anon, authenticated;

commit;