-- Ejecuta una sola vez para habilitar los votos compartidos de Winkle.
insert into public.community_characters (id) values ('winkle')
on conflict (id) do nothing;
