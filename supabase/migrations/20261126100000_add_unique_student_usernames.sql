alter table public.profiles
  add column if not exists username text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_username_format_check'
  ) then
    alter table public.profiles
      add constraint profiles_username_format_check
      check (username is null or username ~ '^[a-z0-9_]{3,20}$');
  end if;
end
$$;

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username))
  where username is not null;

create or replace function public.is_student_username_available_v1(p_username text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select
    (select auth.uid()) is not null
    and p_username ~ '^[a-z0-9_]{3,20}$'
    and not exists (
      select 1
      from public.profiles p
      where lower(p.username) = lower(p_username)
        and p.user_id <> (select auth.uid())
    );
$function$;

revoke all on function public.is_student_username_available_v1(text) from public;
revoke all on function public.is_student_username_available_v1(text) from anon;
grant execute on function public.is_student_username_available_v1(text) to authenticated;
