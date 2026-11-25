create or replace function public.get_student_public_profile_v1(p_user_id uuid)
returns table (
  user_id uuid,
  display_name text,
  stage text,
  badge text,
  avatar_url text,
  bio text,
  username text,
  question_points bigint,
  is_developer boolean
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select
    p.user_id,
    p.display_name,
    p.stage,
    p.badge,
    p.avatar_url,
    p.bio,
    coalesce(
      nullif(btrim(u.raw_user_meta_data ->> 'username'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'user_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'preferred_username'), '')
    ) as username,
    null::bigint as question_points,
    (
      lower(coalesce(u.email, '')) = 'dhwa44430@gmail.com'
      and u.email_confirmed_at is not null
    ) as is_developer
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where auth.uid() is not null
    and p.user_id = p_user_id
    and exists (
      select 1 from public.chat_messages m
      where m.user_id = p.user_id
        and m.deleted_at is null
        and m.hidden_at is null
    )
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid())
    );
$function$;

revoke all on function public.get_student_public_profile_v1(uuid) from public, anon;
grant execute on function public.get_student_public_profile_v1(uuid) to authenticated;