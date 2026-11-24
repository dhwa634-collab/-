alter table public.profiles
  add column if not exists bio text;

alter table public.profiles
  drop constraint if exists profiles_bio_length_check;

alter table public.profiles
  add constraint profiles_bio_length_check
  check (bio is null or char_length(btrim(bio)) <= 180);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop function if exists public.get_chat_profiles_v2(uuid[]);
create function public.get_chat_profiles_v2(user_ids uuid[])
returns table (
  user_id uuid,
  display_name text,
  stage text,
  badge text,
  avatar_url text,
  bio text
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select p.user_id, p.display_name, p.stage, p.badge, p.avatar_url, p.bio
  from public.profiles p
  where auth.uid() is not null
    and p.user_id = any(user_ids)
    and exists (
      select 1
      from public.chat_messages m
      where m.user_id = p.user_id
        and m.deleted_at is null
        and m.hidden_at is null
    )
    and not exists (
      select 1
      from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid())
    );
$function$;

revoke all on function public.get_chat_profiles_v2(uuid[]) from public;
revoke all on function public.get_chat_profiles_v2(uuid[]) from anon;
grant execute on function public.get_chat_profiles_v2(uuid[]) to authenticated;
