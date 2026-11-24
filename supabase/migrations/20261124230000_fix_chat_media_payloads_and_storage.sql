-- Extend chat message payloads with image media while keeping each payload type strict.
alter table public.chat_messages
  drop constraint if exists chat_message_payload_valid;

alter table public.chat_messages
  add constraint chat_message_payload_valid
  check (
    (message_type = 'text'
      and body is not null
      and char_length(btrim(body)) between 1 and 2000
      and sticker_id is null
      and storage_path is null)
    or
    (message_type = 'builtin_sticker'
      and sticker_id is not null
      and char_length(sticker_id) between 1 and 80
      and body is null
      and storage_path is null)
    or
    (message_type in ('custom_sticker', 'voice', 'image')
      and storage_path is not null
      and char_length(btrim(storage_path)) between 1 and 500
      and body is null
      and sticker_id is null)
  );

alter table public.chat_messages
  drop constraint if exists chat_messages_message_type_check;

alter table public.chat_messages
  add constraint chat_messages_message_type_check
  check (message_type = any (array[
    'text', 'builtin_sticker', 'custom_sticker', 'voice', 'image'
  ]));

-- Private image bucket for chat attachments; files remain readable only to signed-in students.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media', 'chat-media', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists chat_media_insert_own on storage.objects;
create policy chat_media_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists chat_media_read_authenticated on storage.objects;
create policy chat_media_read_authenticated
on storage.objects for select to authenticated
using (bucket_id = 'chat-media');

drop policy if exists chat_media_delete_own on storage.objects;
create policy chat_media_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
