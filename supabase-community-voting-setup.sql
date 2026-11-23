-- Votación comunitaria del Manual del Guardián
-- Ejecuta este archivo completo en Supabase > SQL Editor.
-- Cuenta un voto por identificador de navegador; no verifica una identidad humana.
-- La página usa solo la clave publicable, nunca la service_role.

begin;

create table if not exists public.community_characters (
  id text primary key
);

create table if not exists public.community_character_votes (
  voter_hash text primary key check (voter_hash ~ '^[0-9a-f]{64}$'),
  character_id text not null references public.community_characters(id) on update cascade on delete restrict,
  updated_at timestamptz not null default now()
);

alter table public.community_characters enable row level security;
alter table public.community_character_votes enable row level security;
revoke all on table public.community_characters from public, anon, authenticated;
revoke all on table public.community_character_votes from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

insert into public.community_characters (id) values
  ('24'), ('agrippa'), ('aigis'), ('alva'), ('arachne'), ('caecus'),
  ('caraboo'), ('castor'), ('corposant'), ('daffodil'), ('doll'),
  ('doll-infierno'), ('doresain'), ('erica'), ('faint'), ('faros'),
  ('goliat'), ('hameln'), ('helot'), ('helot-catena'), ('karen'),
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

create or replace function public.get_community_character_my_vote(p_voter_hash text)
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select votes.character_id
  from public.community_character_votes as votes
  where votes.voter_hash = p_voter_hash
    and p_voter_hash ~ '^[0-9a-f]{64}$'
  limit 1;
$function$;

create or replace function public.set_community_character_vote(p_voter_hash text, p_character_id text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if p_voter_hash is null or p_voter_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid voter identifier';
  end if;

  if not exists (
    select 1 from public.community_characters where id = p_character_id
  ) then
    raise exception 'Unknown character';
  end if;

  insert into public.community_character_votes (voter_hash, character_id)
  values (p_voter_hash, p_character_id)
  on conflict (voter_hash) do update
    set character_id = excluded.character_id,
        updated_at = now();
end;
$function$;

revoke all on function public.get_community_character_vote_counts() from public, anon, authenticated;
revoke all on function public.get_community_character_my_vote(text) from public, anon, authenticated;
revoke all on function public.set_community_character_vote(text, text) from public, anon, authenticated;
grant execute on function public.get_community_character_vote_counts() to anon, authenticated;
grant execute on function public.get_community_character_my_vote(text) to anon, authenticated;
grant execute on function public.set_community_character_vote(text, text) to anon, authenticated;

commit;