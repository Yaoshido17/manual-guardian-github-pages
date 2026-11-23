-- Ejecuta una sola vez para habilitar los votos compartidos de Wanda.
insert into public.community_characters (id) values ('wanda')
on conflict (id) do nothing;
