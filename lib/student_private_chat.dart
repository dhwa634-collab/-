import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _dmDb = Supabase.instance.client;

class StudentPublicProfileScreen extends StatefulWidget {
  const StudentPublicProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  State<StudentPublicProfileScreen> createState() => _StudentPublicProfileScreenState();
}

class _StudentPublicProfileScreenState extends State<StudentPublicProfileScreen> {
  late Future<Map<String, dynamic>?> profile;
  bool blocked = false, busy = false;

  @override
  void initState() {
    super.initState();
    profile = _load();
    _loadBlock();
  }

  Future<Map<String, dynamic>?> _load() async {
    final row = await _dmDb.from('profiles')
      .select('user_id,display_name,stage,badge,avatar_url,bio')
      .eq('user_id', widget.userId).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> _loadBlock() async {
    final me = _dmDb.auth.currentUser?.id;
    if (me == null || me == widget.userId) return;
    try {
      final row = await _dmDb.from('user_blocks').select('blocked_id')
        .eq('blocker_id', me).eq('blocked_id', widget.userId).maybeSingle();
      if (mounted) setState(() => blocked = row != null);
    } catch (_) {}
  }

  Future<void> _toggleBlock() async {
    final me = _dmDb.auth.currentUser?.id;
    if (me == null || busy) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: Text(blocked ? 'إلغاء الحظر؟' : 'حظر هذا المستخدم؟'),
        content: Text(blocked
          ? 'سيتمكن هذا المستخدم من مراسلتك مجدداً.'
          : 'لن تتمكن أنت وهذا المستخدم من تبادل الرسائل الخاصة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(blocked ? 'إلغاء الحظر' : 'حظر')),
        ],
      ));
    if (ok != true) return;
    setState(() => busy = true);
    try {
      if (blocked) {
        await _dmDb.from('user_blocks').delete()
          .eq('blocker_id', me).eq('blocked_id', widget.userId);
      } else {
        await _dmDb.from('user_blocks').insert({'blocker_id': me, 'blocked_id': widget.userId});
      }
      if (mounted) setState(() => blocked = !blocked);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تنفيذ العملية حالياً.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF091426),
      appBar: AppBar(backgroundColor: const Color(0xFF091426),
        foregroundColor: Colors.white, elevation: 0),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: profile,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) return const Center(child: Text('الملف الشخصي غير متاح.'));
          final name = (p['display_name'] ?? 'طالب').toString();
          final avatar = p['avatar_url']?.toString();
          final isMe = _dmDb.auth.currentUser?.id == widget.userId;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF172B43),
                borderRadius: BorderRadius.circular(26),
                image: avatar != null && avatar.startsWith('http')
                  ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null,
              ),
              child: Stack(fit: StackFit.expand, children: [
                if (avatar == null || !avatar.startsWith('http'))
                  const Center(child: Icon(Icons.person_rounded, size: 100, color: Colors.white38)),
                DecoratedBox(decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9000000)]))),
                Positioned(right: 18, bottom: 20, left: 18,
                  child: Text(name, style: const TextStyle(color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.w900))),
              ]),
            ),
            const SizedBox(height: 18),
            Center(child: Text('معرّف العضو: ${widget.userId.substring(0, 8)}',
              style: const TextStyle(color: Colors.white60, fontSize: 14))),
            if (!isMe) ...[
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _ProfileAction(
                  icon: Icons.chat_bubble_rounded, label: 'مراسلة',
                  onTap: blocked ? null : () {
                    final me = _dmDb.auth.currentUser;
                    if (me == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('سجّل الدخول أولاً حتى تراسل الطلاب.')));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      StudentPrivateChatScreen(
                        peerId: widget.userId,
                        peerName: name,
                        peerAvatar: avatar,
                        peerBadge: p['badge']?.toString(),
                      )));
                  })),
                const SizedBox(width: 14),
                Expanded(child: _ProfileAction(
                  icon: Icons.block_rounded, label: blocked ? 'محظور' : 'حظر',
                  danger: true, onTap: busy ? null : _toggleBlock)),
              ]),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: const Color(0xFF15365B),
                borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _ProfileField(label: 'النبذة',
                  value: (p['bio'] ?? '').toString().isEmpty ? 'لا توجد نبذة بعد.' : p['bio'].toString()),
                const SizedBox(height: 24),
                _ProfileField(label: 'الصف', value: (p['stage'] ?? 'غير محدد').toString()),
                if ((p['badge'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _ProfileField(label: 'الصفة', value: p['badge'].toString()),
                ],
              ]),
            ),
          ]);
        },
      ),
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF173B66), borderRadius: BorderRadius.circular(30),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(30),
      child: SizedBox(height: 112, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: danger ? const Color(0xFFE45D68) : const Color(0xFFFFD34F)),
          const SizedBox(height: 9),
          Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: danger ? const Color(0xFFE45D68) : Colors.white)),
        ],
      )),
    ),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.5)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
    ],
  );
}

class StudentPrivateChatScreen extends StatefulWidget {
  const StudentPrivateChatScreen({super.key, required this.peerId, required this.peerName,
    this.peerAvatar, this.peerBadge});
  final String peerId, peerName;
  final String? peerAvatar, peerBadge;
  @override
  State<StudentPrivateChatScreen> createState() => _StudentPrivateChatScreenState();
}

class _StudentPrivateChatScreenState extends State<StudentPrivateChatScreen> {
  final input = TextEditingController();
  bool sending = false;
  late final Stream<List<Map<String, dynamic>>> messages;
  static const emojis = ['😀','😃','😄','😁','😆','😅','😂','🤣','😊','😉','😍','🥰',
    '😘','😎','🤩','🥳','😭','😢','😡','👍','👏','🙌','🙏','💪','❤️','💛','💚','💙',
    '💜','✨','🌟','🔥','🎉','📚','✏️','📝','🎯','🌹'];

  @override
  void initState() {
    super.initState();
    messages = _dmDb.from('direct_messages').stream(primaryKey: ['id'])
      .order('created_at', ascending: false);
  }

  Future<void> send() async {
    final me = _dmDb.auth.currentUser;
    final body = input.text.trim();
    if (me == null || body.isEmpty || sending) return;
    if (body.length > 2000) return;
    setState(() => sending = true);
    try {
      await _dmDb.from('direct_messages').insert({
        'sender_id': me.id, 'receiver_id': widget.peerId, 'body': body,
      });
      input.clear();
    } on PostgrestException catch (e) {
      _toast(e.code == '42501'
        ? 'تعذر الإرسال بسبب إعدادات الخصوصية أو الحظر.'
        : 'تعذر إرسال الرسالة: ${e.message}');
    } catch (_) {
      _toast('تعذر إرسال الرسالة. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _emojiPicker() async {
    await showModalBottomSheet<void>(
      context: context, backgroundColor: const Color(0xFF17232E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(textDirection: TextDirection.ltr,
        child: SafeArea(child: SizedBox(height: MediaQuery.sizeOf(ctx).height * .42,
          child: GridView.builder(padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: emojis.length,
            itemBuilder: (_, i) => InkWell(
              onTap: () {
                final v = input.value;
                final start = v.selection.isValid ? v.selection.start : v.text.length;
                final end = v.selection.isValid ? v.selection.end : v.text.length;
                final text = v.text.replaceRange(start, end, emojis[i]);
                input.value = TextEditingValue(text: text,
                  selection: TextSelection.collapsed(offset: start + emojis[i].length));
                Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 26))),
            ),
          )),
        )),
    );
  }

  @override
  void dispose() { input.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF091426),
      appBar: AppBar(backgroundColor: const Color(0xFF17232E), foregroundColor: Colors.white,
        title: Row(children: [
          CircleAvatar(radius: 19,
            backgroundImage: widget.peerAvatar != null && widget.peerAvatar!.startsWith('http')
              ? NetworkImage(widget.peerAvatar!) : null,
            child: widget.peerAvatar == null || !widget.peerAvatar!.startsWith('http')
              ? const Icon(Icons.person_rounded) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
              Text(widget.peerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              if (widget.peerBadge?.isNotEmpty == true)
                Text(widget.peerBadge!, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ])),
        ])),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: messages,
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('تعذر تحميل المحادثة الخاصة.'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final me = _dmDb.auth.currentUser?.id;
            final rows = snap.data!.where((r) =>
              (r['sender_id'] == me && r['receiver_id'] == widget.peerId) ||
              (r['sender_id'] == widget.peerId && r['receiver_id'] == me)).toList();
            if (rows.isEmpty) return const Center(child: Text('ابدأ المحادثة برسالة لطيفة 💙',
              style: TextStyle(color: Colors.white70)));
            return ListView.builder(reverse: true, padding: const EdgeInsets.all(12),
              itemCount: rows.length, itemBuilder: (_, i) {
                final row = rows[i];
                final mine = row['sender_id'] == me;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFF23486B) : const Color(0xFF172B43),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(mine ? 5 : 18),
                        bottomRight: Radius.circular(mine ? 18 : 5))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text((row['body'] ?? '').toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4)),
                      const SizedBox(height: 4),
                      Text(_time(row['created_at']),
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ]),
                  ),
                );
              });
          },
        )),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: const Color(0xFF343434), width: 1.2)),
            child: Row(textDirection: TextDirection.ltr, children: [
              IconButton(onPressed: _emojiPicker,
                icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 30)),
              Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4,
                maxLength: 2000, onSubmitted: (_) => send(), textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white, fontSize: 17),
                decoration: const InputDecoration(hintText: 'الرسالة',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 17),
                  counterText: '', border: InputBorder.none, isDense: true))),
              Container(width: 52, height: 52,
                decoration: const BoxDecoration(color: Color(0xFF5278EE), shape: BoxShape.circle),
                child: IconButton(onPressed: sending ? null : send,
                  icon: sending ? const SizedBox(width: 19, height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 25))),
            ]),
          ),
        )),
      ]),
    ),
  );

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
