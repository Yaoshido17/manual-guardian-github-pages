-- Ejecuta una sola vez para habilitar los votos compartidos de Horla.
insert into public.community_characters (id) values ('horla')
on conflict (id) do nothing;
