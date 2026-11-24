revoke all on function public.get_chat_profiles_v2(uuid[]) from public;
revoke all on function public.get_chat_profiles_v2(uuid[]) from anon;
grant execute on function public.get_chat_profiles_v2(uuid[]) to authenticated;

revoke all on function public.get_chat_profiles(uuid[]) from public;
revoke all on function public.get_chat_profiles(uuid[]) from anon;
revoke all on function public.get_chat_profiles(uuid[]) from authenticated;
