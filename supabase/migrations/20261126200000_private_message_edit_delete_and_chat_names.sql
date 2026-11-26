alter table public.direct_messages
  add column if not exists edited_at timestamptz;

drop policy if exists direct_messages_update_own on public.direct_messages;
create policy direct_messages_update_own on public.direct_messages
for update to authenticated
using (sender_id = (select auth.uid()))
with check (sender_id = (select auth.uid()));

drop policy if exists direct_messages_delete_own on public.direct_messages;
create policy direct_messages_delete_own on public.direct_messages
for delete to authenticated
using (sender_id = (select auth.uid()));

grant update (body, edited_at) on public.direct_messages to authenticated;
grant delete on public.direct_messages to authenticated;

create or replace function public.get_student_chat_profiles_v1(p_user_ids uuid[])
returns table (user_id uuid, display_name text, username text, avatar_url text, badge text, is_developer boolean)
language sql stable security definer
set search_path = pg_catalog, public, auth
as $$
  select u.id,
    coalesce(nullif(btrim(p.display_name), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'given_name'), ''),
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'طالب'),
    coalesce(nullif(btrim(p.username), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'username'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'user_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'preferred_username'), '')),
    p.avatar_url, coalesce(p.badge, 'طالب'),
    (lower(coalesce(u.email, '')) = 'dhwa44430@gmail.com' and u.email_confirmed_at is not null)
  from auth.users u left join public.profiles p on p.user_id = u.id
  where auth.uid() is not null
    and u.id = any(coalesce(p_user_ids, array[]::uuid[]))
    and (u.id = auth.uid()
      or exists (select 1 from public.direct_messages dm
        where (dm.sender_id = auth.uid() and dm.receiver_id = u.id)
           or (dm.receiver_id = auth.uid() and dm.sender_id = u.id))
      or exists (select 1 from public.chat_messages cm
        where cm.user_id = u.id and cm.deleted_at is null and cm.hidden_at is null))
    and (u.id = auth.uid() or not exists (select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = u.id)
         or (b.blocker_id = u.id and b.blocked_id = auth.uid())));
$$;
revoke all on function public.get_student_chat_profiles_v1(uuid[]) from public;
grant execute on function public.get_student_chat_profiles_v1(uuid[]) to authenticated;
