create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint direct_messages_distinct_users check (sender_id <> receiver_id),
  constraint direct_messages_body_length check (char_length(btrim(body)) between 1 and 2000)
);
create index if not exists direct_messages_sender_receiver_created_idx
  on public.direct_messages (sender_id, receiver_id, created_at desc);
create index if not exists direct_messages_receiver_sender_created_idx
  on public.direct_messages (receiver_id, sender_id, created_at desc);
alter table public.direct_messages enable row level security;
drop policy if exists direct_messages_read_participants on public.direct_messages;
create policy direct_messages_read_participants
on public.direct_messages for select to authenticated
using (
  (select auth.uid()) is not null
  and ((select auth.uid()) = sender_id or (select auth.uid()) = receiver_id)
  and not exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id =
      case when sender_id = (select auth.uid()) then receiver_id else sender_id end)
       or (b.blocker_id =
      case when sender_id = (select auth.uid()) then receiver_id else sender_id end
      and b.blocked_id = (select auth.uid()))
  )
);
drop policy if exists direct_messages_insert_sender on public.direct_messages;
create policy direct_messages_insert_sender
on public.direct_messages for insert to authenticated
with check (
  (select auth.uid()) is not null
  and sender_id = (select auth.uid())
  and sender_id <> receiver_id
  and not exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = sender_id and b.blocked_id = receiver_id)
       or (b.blocker_id = receiver_id and b.blocked_id = sender_id)
  )
);
grant select, insert on public.direct_messages to authenticated;
revoke all on public.direct_messages from anon;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'direct_messages'
  ) then
    alter publication supabase_realtime add table public.direct_messages;
  end if;
end
$$;