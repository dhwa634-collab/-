-- Expose only a boolean developer flag to authenticated chat readers.
-- Never return the account email to other users or trust editable user_metadata.
drop function if exists public.get_chat_profiles_v2(uuid[]);

create function public.get_chat_profiles_v2(user_ids uuid[])
returns table (
  user_id uuid,
  display_name text,
  stage text,
  badge text,
  avatar_url text,
  bio text,
  is_developer boolean
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select
    p.user_id,
    p.display_name,
    p.stage,
    p.badge,
    p.avatar_url,
    p.bio,
    (u.id is not null) as is_developer
  from public.profiles p
  left join auth.users u
    on u.id = p.user_id
   and lower(u.email) = 'dhwa44430@gmail.com'
   and u.email_confirmed_at is not null
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
