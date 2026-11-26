alter table public.direct_messages
  add column if not exists read_at timestamptz;

create table if not exists public.news (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 180),
  body text not null check (char_length(btrim(body)) between 1 and 12000),
  category text not null default 'updates'
    check (category in ('updates','tips','students','app')),
  pinned boolean not null default false,
  published_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists news_created_at_idx on public.news (created_at desc);
create index if not exists news_pinned_created_at_idx on public.news (pinned desc, created_at desc);

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  type text not null check (type in ('direct_message','news')),
  title text not null check (char_length(title) between 1 and 180),
  body text not null default '' check (char_length(body) <= 500),
  reference_id uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists user_notifications_recipient_unread_idx
  on public.user_notifications (recipient_id, created_at desc) where read_at is null;
create index if not exists user_notifications_recipient_created_idx
  on public.user_notifications (recipient_id, created_at desc);

alter table public.news enable row level security;
alter table public.user_notifications enable row level security;
drop policy if exists news_public_read on public.news;
create policy news_public_read on public.news for select to anon, authenticated using (true);
drop policy if exists news_developer_insert on public.news;
create policy news_developer_insert on public.news for insert to authenticated
with check (published_by = (select auth.uid()) and exists (
  select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.username = '1'
));
drop policy if exists news_developer_update on public.news;
create policy news_developer_update on public.news for update to authenticated
using (exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.username = '1'))
with check (exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.username = '1'));
drop policy if exists news_developer_delete on public.news;
create policy news_developer_delete on public.news for delete to authenticated
using (exists (select 1 from public.profiles p where p.user_id = (select auth.uid()) and p.username = '1'));
drop policy if exists user_notifications_read_own on public.user_notifications;
create policy user_notifications_read_own on public.user_notifications
for select to authenticated using (recipient_id = (select auth.uid()));
grant select on public.news to anon, authenticated;
grant insert, update, delete on public.news to authenticated;
grant select on public.user_notifications to authenticated;

create or replace function public.mark_direct_messages_read(p_sender_id uuid)
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare affected integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.direct_messages set read_at = now()
  where sender_id = p_sender_id and receiver_id = auth.uid() and read_at is null
    and not exists (select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p_sender_id)
         or (b.blocker_id = p_sender_id and b.blocked_id = auth.uid()));
  get diagnostics affected = row_count;
  return affected;
end; $$;

create or replace function public.mark_user_notification_read(p_notification_id uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare affected integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.user_notifications set read_at = now()
  where id = p_notification_id and recipient_id = auth.uid() and read_at is null;
  get diagnostics affected = row_count;
  return affected > 0;
end; $$;
revoke all on function public.mark_direct_messages_read(uuid) from public;
revoke all on function public.mark_user_notification_read(uuid) from public;
grant execute on function public.mark_direct_messages_read(uuid) to authenticated;
grant execute on function public.mark_user_notification_read(uuid) to authenticated;

create or replace function public.set_news_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists news_set_updated_at on public.news;
create trigger news_set_updated_at before update on public.news
for each row execute function public.set_news_updated_at();

create or replace function public.notify_direct_message_insert()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare sender_name text;
begin
  if exists (select 1 from public.user_blocks b
    where (b.blocker_id = new.sender_id and b.blocked_id = new.receiver_id)
       or (b.blocker_id = new.receiver_id and b.blocked_id = new.sender_id)) then
    return new;
  end if;
  select coalesce(p.display_name, 'رسالة جديدة') into sender_name
  from public.profiles p where p.user_id = new.sender_id;
  insert into public.user_notifications(recipient_id,actor_id,type,title,body,reference_id)
  values(new.receiver_id,new.sender_id,'direct_message',coalesce(sender_name,'رسالة جديدة'),left(new.body,180),new.id);
  return new;
end; $$;
drop trigger if exists direct_messages_notify_insert on public.direct_messages;
create trigger direct_messages_notify_insert after insert on public.direct_messages
for each row execute function public.notify_direct_message_insert();

create or replace function public.notify_news_insert()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.user_notifications(recipient_id,actor_id,type,title,body,reference_id)
  select p.user_id,new.published_by,'news',new.title,left(new.body,180),new.id
  from public.profiles p where new.published_by is null or p.user_id <> new.published_by;
  return new;
end; $$;
drop trigger if exists news_notify_insert on public.news;
create trigger news_notify_insert after insert on public.news
for each row execute function public.notify_news_insert();

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='news') then
    alter publication supabase_realtime add table public.news;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='user_notifications') then
    alter publication supabase_realtime add table public.user_notifications;
  end if;
end $$;
