-- Ejecuta una sola vez para habilitar los votos compartidos de Liz.
insert into public.community_characters (id) values ('liz')
on conflict (id) do nothing;
