-- Group chat moderation: database-enforced roles, mutes, bans and message removal.
-- Safe to re-run. The reserved @1 account is seeded as owner below.
-- Add more moderators only by inserting their auth.users UUID from a trusted SQL session.

create table if not exists public.chat_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'moderator' check (role in ('owner','admin','moderator')),
  created_at timestamptz not null default now()
);
create table if not exists public.chat_user_mutes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  muted_until timestamptz,
  is_permanent boolean not null default false,
  reason text not null default '',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  constraint chat_user_mutes_duration_check check (
    (is_permanent and muted_until is null) or (not is_permanent and muted_until is not null)
  )
);
create table if not exists public.chat_user_bans (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reason text not null default '',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.chat_admins enable row level security;
alter table public.chat_user_mutes enable row level security;
alter table public.chat_user_bans enable row level security;

drop policy if exists chat_admins_read_self on public.chat_admins;
create policy chat_admins_read_self on public.chat_admins
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists chat_mutes_read_self on public.chat_user_mutes;
create policy chat_mutes_read_self on public.chat_user_mutes
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists chat_bans_read_self on public.chat_user_bans;
create policy chat_bans_read_self on public.chat_user_bans
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.chat_admins, public.chat_user_mutes, public.chat_user_bans to authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.chat_admins, public.chat_user_mutes, public.chat_user_bans from anon, authenticated;
grant insert, update on public.chat_user_mutes, public.chat_user_bans to authenticated;



insert into public.chat_admins (user_id, role)
values ('7244dd5e-1779-40b5-b995-809fcfcade7f'::uuid, 'owner')
on conflict (user_id) do update set role = 'owner';

create or replace function public.is_group_chat_admin()
returns boolean language sql stable security invoker
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.chat_admins a where a.user_id = (select auth.uid()));
$$;
revoke all on function public.is_group_chat_admin() from public, anon;
grant execute on function public.is_group_chat_admin() to authenticated;

drop policy if exists chat_mutes_read_admin on public.chat_user_mutes;
create policy chat_mutes_read_admin on public.chat_user_mutes
  for select to authenticated using (public.is_group_chat_admin());
drop policy if exists chat_bans_read_admin on public.chat_user_bans;
create policy chat_bans_read_admin on public.chat_user_bans
  for select to authenticated using (public.is_group_chat_admin());
drop policy if exists chat_mutes_admin_insert on public.chat_user_mutes;
create policy chat_mutes_admin_insert on public.chat_user_mutes
  for insert to authenticated with check (
    public.is_group_chat_admin() and created_by = (select auth.uid())
  );
drop policy if exists chat_mutes_admin_update on public.chat_user_mutes;
create policy chat_mutes_admin_update on public.chat_user_mutes
  for update to authenticated using (public.is_group_chat_admin())
  with check (public.is_group_chat_admin() and created_by = (select auth.uid()));
drop policy if exists chat_bans_admin_insert on public.chat_user_bans;
create policy chat_bans_admin_insert on public.chat_user_bans
  for insert to authenticated with check (
    public.is_group_chat_admin() and created_by = (select auth.uid())
  );
drop policy if exists chat_bans_admin_update on public.chat_user_bans;
create policy chat_bans_admin_update on public.chat_user_bans
  for update to authenticated using (public.is_group_chat_admin())
  with check (public.is_group_chat_admin() and created_by = (select auth.uid()));

create or replace function public.get_my_group_chat_status()
returns jsonb language sql stable security invoker
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'is_banned', exists (select 1 from public.chat_user_bans b where b.user_id = (select auth.uid())),
    'is_muted', exists (select 1 from public.chat_user_mutes m
      where m.user_id = (select auth.uid()) and (m.is_permanent or m.muted_until > now())),
    'is_permanent', coalesce((select m.is_permanent from public.chat_user_mutes m
      where m.user_id = (select auth.uid()) and (m.is_permanent or m.muted_until > now()) limit 1), false),
    'muted_until', (select m.muted_until from public.chat_user_mutes m
      where m.user_id = (select auth.uid()) and (m.is_permanent or m.muted_until > now()) limit 1)
  );
$$;
revoke all on function public.get_my_group_chat_status() from public, anon;
grant execute on function public.get_my_group_chat_status() to authenticated;

drop policy if exists chat_messages_moderation_insert_guard on public.chat_messages;
create policy chat_messages_moderation_insert_guard on public.chat_messages as restrictive
  for insert to authenticated with check (
    not exists (select 1 from public.chat_user_bans b where b.user_id = (select auth.uid()))
    and not exists (select 1 from public.chat_user_mutes m
      where m.user_id = (select auth.uid()) and (m.is_permanent or m.muted_until > now()))
  );
drop policy if exists chat_messages_moderation_read_guard on public.chat_messages;
create policy chat_messages_moderation_read_guard on public.chat_messages as restrictive
  for select to authenticated using (
    not exists (select 1 from public.chat_user_bans b where b.user_id = (select auth.uid()))
  );

drop policy if exists chat_messages_admin_update on public.chat_messages;
create policy chat_messages_admin_update on public.chat_messages
  for update to authenticated using (public.is_group_chat_admin())
  with check (public.is_group_chat_admin());

create or replace function public.admin_delete_group_chat_message(p_message_id uuid)
returns void language plpgsql security invoker
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.chat_admins a where a.user_id = auth.uid()
  ) then raise exception 'not_authorized' using errcode = '42501'; end if;
  update public.chat_messages set deleted_at = coalesce(deleted_at, now()) where id = p_message_id;
  if not found then raise exception 'message_not_found' using errcode = 'P0002'; end if;
end;
$$;

create or replace function public.admin_mute_group_chat_user(
  p_user_id uuid, p_duration_hours integer, p_reason text default ''
)
returns void language plpgsql security invoker
set search_path = pg_catalog, public
as $$
declare v_admin_id uuid := auth.uid(); v_permanent boolean;
begin
  if v_admin_id is null or not exists (
    select 1 from public.chat_admins a where a.user_id = v_admin_id
  ) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_user_id is null or p_user_id = v_admin_id then
    raise exception 'invalid_target' using errcode = '22023';
  end if;
  if p_duration_hours not in (0, 1, 24) then
    raise exception 'invalid_mute_duration' using errcode = '22023';
  end if;
  if exists (select 1 from public.chat_admins a where a.user_id = p_user_id) then
    raise exception 'cannot_moderate_admin' using errcode = '42501';
  end if;
  v_permanent := p_duration_hours = 0;
  insert into public.chat_user_mutes (user_id, muted_until, is_permanent, reason, created_by)
  values (p_user_id,
    case when v_permanent then null else now() + make_interval(hours => p_duration_hours) end,
    v_permanent, left(coalesce(p_reason, ''), 300), v_admin_id)
  on conflict (user_id) do update set
    muted_until = excluded.muted_until, is_permanent = excluded.is_permanent,
    reason = excluded.reason, created_by = excluded.created_by, created_at = now();
end;
$$;

create or replace function public.admin_ban_group_chat_user(p_user_id uuid, p_reason text default '')
returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare v_admin_id uuid := auth.uid();
begin
  if v_admin_id is null or not exists (
    select 1 from public.chat_admins a where a.user_id = v_admin_id
  ) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_user_id is null or p_user_id = v_admin_id then
    raise exception 'invalid_target' using errcode = '22023';
  end if;
  if exists (select 1 from public.chat_admins a where a.user_id = p_user_id) then
    raise exception 'cannot_moderate_admin' using errcode = '42501';
  end if;
  insert into public.chat_user_bans (user_id, reason, created_by)
  values (p_user_id, left(coalesce(p_reason, ''), 300), v_admin_id)
  on conflict (user_id) do update set
    reason = excluded.reason, created_by = excluded.created_by, created_at = now();
end;
$$;

revoke all on function public.admin_delete_group_chat_message(uuid) from public, anon;
revoke all on function public.admin_mute_group_chat_user(uuid, integer, text) from public, anon;
revoke all on function public.admin_ban_group_chat_user(uuid, text) from public, anon;
grant execute on function public.admin_delete_group_chat_message(uuid) to authenticated;
grant execute on function public.admin_mute_group_chat_user(uuid, integer, text) to authenticated;
grant execute on function public.admin_ban_group_chat_user(uuid, text) to authenticated;
