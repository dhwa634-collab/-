-- Manual Supabase SQL for chat retention and email privacy hardening.
-- Review and run in Supabase SQL Editor as the postgres/database owner.
-- This script is intentionally NOT executed automatically by the app or GitHub Actions.

begin;

-- Public profile rows contain public profile fields only; the live schema was
-- inspected and has no email column. Keep profile row access owner-only.
alter table public.profiles enable row level security;
revoke all on table public.profiles from public, anon;
grant select, insert, update on table public.profiles to authenticated;

-- Keep the existing profiles_select_self / profiles_insert_self /
-- profiles_update_self policies. They already constrain user_id = auth.uid().
-- Do not expose auth.users or auth.identities through the public Data API.

-- Chat profile RPC: never derive a display name from an email address.
create or replace function public.get_student_chat_profiles_v1(p_user_ids uuid[])
returns table(
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  badge text,
  is_developer boolean
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select
    u.id,
    coalesce(
      nullif(btrim(p.display_name), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'given_name'), ''),
      'طالب'
    ),
    coalesce(
      nullif(btrim(p.username), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'username'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'user_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'preferred_username'), '')
    ),
    p.avatar_url,
    coalesce(p.badge, 'طالب'),
    (
      lower(coalesce(u.email, '')) = 'dhwa44430@gmail.com'
      and u.email_confirmed_at is not null
    )
  from auth.users u
  left join public.profiles p on p.user_id = u.id
  where auth.uid() is not null
    and u.id = any(coalesce(p_user_ids, array[]::uuid[]))
    and (
      u.id = auth.uid()
      or exists (
        select 1 from public.direct_messages dm
        where (dm.sender_id = auth.uid() and dm.receiver_id = u.id)
           or (dm.receiver_id = auth.uid() and dm.sender_id = u.id)
      )
      or exists (
        select 1 from public.chat_messages cm
        where cm.user_id = u.id
          and cm.deleted_at is null
          and cm.hidden_at is null
      )
    )
    and (
      u.id = auth.uid()
      or not exists (
        select 1 from public.user_blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = u.id)
           or (b.blocker_id = u.id and b.blocked_id = auth.uid())
      )
    );
$function$;

revoke all on function public.get_student_chat_profiles_v1(uuid[]) from public, anon;
grant execute on function public.get_student_chat_profiles_v1(uuid[]) to authenticated;

-- Direct-message notification content is generic. Never copy an email-like
-- display fallback or the raw message body into the notification preview.
create or replace function public.notify_direct_message_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  sender_name text;
begin
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = new.sender_id and b.blocked_id = new.receiver_id)
       or (b.blocker_id = new.receiver_id and b.blocked_id = new.sender_id)
  ) then
    return new;
  end if;

  select coalesce(
    nullif(btrim(p.display_name), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
    'طالب'
  )
  into sender_name
  from auth.users u
  left join public.profiles p on p.user_id = u.id
  where u.id = new.sender_id;

  insert into public.user_notifications
    (recipient_id, actor_id, type, title, body, reference_id)
  values
    (new.receiver_id, new.sender_id, 'direct_message',
     coalesce(sender_name, 'رسالة جديدة'),
     'أرسل لك رسالة خاصة',
     new.id);

  return new;
end;
$function$;

-- Supporting indexes keep the scheduled retention deletes bounded.
create index if not exists chat_messages_created_at_retention_idx
  on public.chat_messages (created_at);
create index if not exists direct_messages_created_at_retention_idx
  on public.direct_messages (created_at);

commit;

-- Enable pg_cron if it is not already enabled in this Supabase project.
-- Supabase's supported installation schema for pg_cron is pg_catalog.
create extension if not exists pg_cron with schema pg_catalog;

-- Replace only this named job; leave every other scheduled job untouched.
do $schedule$
declare
  existing_job record;
begin
  for existing_job in
    select jobid from cron.job
    where jobname = 'delete-chat-messages-after-48-hours'
  loop
    perform cron.unschedule(existing_job.jobid);
  end loop;
end
$schedule$;

-- Run the purge through a private, non-API-exposed schema function.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to postgres;

create or replace function private.purge_chat_messages_older_than_48_hours()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $purge$
begin
  delete from public.direct_messages
  where created_at <= now() - interval '48 hours';

  delete from public.chat_messages
  where created_at <= now() - interval '48 hours';
end;
$purge$;

revoke all on function private.purge_chat_messages_older_than_48_hours()
  from public, anon, authenticated;
grant execute on function private.purge_chat_messages_older_than_48_hours()
  to postgres;

-- Runs every minute; messages are removed at the first run after age >= 48h.
-- FK constraints cascade-delete reactions and reports, and SET NULLs replies.
select cron.schedule(
  'delete-chat-messages-after-48-hours',
  '* * * * *',
  'select private.purge_chat_messages_older_than_48_hours();'
);

-- Verification after running:
-- select jobid, jobname, schedule, command
-- from cron.job
-- where jobname = 'delete-chat-messages-after-48-hours';
--
-- select count(*) from public.profiles; -- profiles has no email column
-- select column_name from information_schema.columns
-- where table_schema = 'public' and table_name = 'profiles';
