revoke all on function public.mark_direct_messages_read(uuid) from public, anon;
revoke all on function public.mark_user_notification_read(uuid) from public, anon;
grant execute on function public.mark_direct_messages_read(uuid) to authenticated;
grant execute on function public.mark_user_notification_read(uuid) to authenticated;
revoke all on function public.notify_direct_message_insert() from public, anon, authenticated;
revoke all on function public.notify_news_insert() from public, anon, authenticated;
revoke all on function public.set_news_updated_at() from public, anon, authenticated;