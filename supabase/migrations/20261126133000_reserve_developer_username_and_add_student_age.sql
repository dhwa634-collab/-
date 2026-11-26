alter table public.profiles
  drop constraint if exists profiles_username_format_check;

alter table public.profiles
  add constraint profiles_username_format_check
  check (
    username is null
    or username ~ '^[a-z0-9_]{3,20}$'
    or username = '1'
  );

alter table public.profiles
  add column if not exists age integer;

alter table public.profiles
  drop constraint if exists profiles_age_range_check;

alter table public.profiles
  add constraint profiles_age_range_check
  check (age is null or age between 10 and 80);

create or replace function public.enforce_student_username_owner_v1()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  account_email text;
begin
  if new.username = '1' then
    select lower(u.email)
      into account_email
      from auth.users u
      where u.id = new.user_id;

    if account_email is distinct from 'dhwa44430@gmail.com' then
      raise exception 'Username 1 is reserved for the developer account'
        using errcode = '23514';
    end if;
  elsif new.username is not null
        and new.username !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'Username must contain 3 to 20 lowercase letters, digits or underscores'
      using errcode = '23514';
  end if;
  return new;
end;
$function$;

revoke all on function public.enforce_student_username_owner_v1() from public;
revoke all on function public.enforce_student_username_owner_v1() from anon;
revoke all on function public.enforce_student_username_owner_v1() from authenticated;

drop trigger if exists profiles_enforce_student_username_owner
  on public.profiles;
create trigger profiles_enforce_student_username_owner
before insert or update of username, user_id on public.profiles
for each row execute function public.enforce_student_username_owner_v1();

create or replace function public.is_student_username_available_v1(p_username text)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  account_email text;
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    return false;
  end if;

  if p_username = '1' then
    select lower(u.email)
      into account_email
      from auth.users u
      where u.id = current_user_id;
    if account_email is distinct from 'dhwa44430@gmail.com' then
      return false;
    end if;
  elsif p_username !~ '^[a-z0-9_]{3,20}$' then
    return false;
  end if;

  return not exists (
    select 1
    from public.profiles p
    where lower(p.username) = lower(p_username)
      and p.user_id <> current_user_id
  );
end;
$function$;

revoke all on function public.is_student_username_available_v1(text) from public;
revoke all on function public.is_student_username_available_v1(text) from anon;
grant execute on function public.is_student_username_available_v1(text) to authenticated;
