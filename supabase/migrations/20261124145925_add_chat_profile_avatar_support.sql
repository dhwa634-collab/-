alter table public.profiles
  add column if not exists avatar_url text;

alter table public.profiles
  drop constraint if exists profiles_avatar_url_http_check;

alter table public.profiles
  add constraint profiles_avatar_url_http_check
  check (avatar_url is null or avatar_url ~* '^https?://[^[:space:]]+$');

create or replace function public.get_chat_profiles_v2(user_ids uuid[])
returns table (
  user_id uuid,
  display_name text,
  stage text,
  badge text,
  avatar_url text
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select p.user_id, p.display_name, p.stage, p.badge, p.avatar_url
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
grant execute on function public.get_chat_profiles_v2(uuid[]) to authenticated;
