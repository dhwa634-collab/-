import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function readDefaultSecretMap(raw: string | undefined): string | undefined {
  if (!raw) return undefined;
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed?.default === "string" ? parsed.default : undefined;
  } catch {
    return undefined;
  }
}

async function removeUserStorage(admin: ReturnType<typeof createClient>, bucketName: string, userId: string) {
  const bucket = admin.storage.from(bucketName);

  async function collect(prefix: string): Promise<string[]> {
    const paths: string[] = [];
    let offset = 0;
    while (true) {
      const { data, error } = await bucket.list(prefix, {
        limit: 100,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) throw new Error(`تعذر فحص ملفات ${bucketName}: ${error.message}`);
      const entries = data ?? [];
      for (const entry of entries) {
        const path = `${prefix}/${entry.name}`;
        if (entry.id) {
          paths.push(path);
        } else {
          paths.push(...await collect(path));
        }
      }
      if (entries.length < 100) break;
      offset += entries.length;
    }
    return paths;
  }

  const paths = await collect(userId);
  for (let index = 0; index < paths.length; index += 100) {
    const batch = paths.slice(index, index + 100);
    const { error } = await bucket.remove(batch);
    if (error) throw new Error(`تعذر حذف ملفات ${bucketName}: ${error.message}`);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "طريقة الطلب غير مدعومة." }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ success: false, error: "انتهت جلسة الدخول. سجّل الدخول مجدداً ثم حاول." }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ success: false, error: "تعذر قراءة طلب حذف الحساب." }, 400);
  }
  if (body.confirm !== true) {
    return json({ success: false, error: "يجب تأكيد حذف الحساب أولاً." }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    ?? readDefaultSecretMap(Deno.env.get("SUPABASE_SECRET_KEYS"));
  if (!url || !serviceKey) {
    return json({ success: false, error: "إعدادات الحذف الآمن غير مكتملة على الخادم." }, 503);
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const accessToken = authorization.slice("Bearer ".length).trim();

  try {
    const { data: userData, error: userError } = await admin.auth.getUser(accessToken);
    const user = userData.user;
    if (userError || !user) {
      return json({ success: false, error: "تعذر التحقق من حسابك. سجّل الدخول مجدداً." }, 401);
    }

    // Remove private media before deleting the Auth user; Supabase blocks user deletion
    // while that user still owns Storage objects.
    await removeUserStorage(admin, "chat-stickers", user.id);
    await removeUserStorage(admin, "chat-voice", user.id);

    const { error: reportsError } = await admin
      .from("chat_reports").delete().eq("reporter_id", user.id);
    if (reportsError) throw new Error("تعذر حذف بلاغات الحساب.");

    const { error: blocksByUserError } = await admin
      .from("user_blocks").delete().eq("blocker_id", user.id);
    if (blocksByUserError) throw new Error("تعذر حذف قائمة الحظر الخاصة بالحساب.");

    const { error: blocksForUserError } = await admin
      .from("user_blocks").delete().eq("blocked_id", user.id);
    if (blocksForUserError) throw new Error("تعذر حذف ارتباطات الحظر الخاصة بالحساب.");

    // Reports linked to the user's messages are removed by the database FK cascade.
    const { error: messagesError } = await admin
      .from("chat_messages").delete().eq("user_id", user.id);
    if (messagesError) throw new Error("تعذر حذف رسائل الحساب.");

    const { error: profileError } = await admin
      .from("profiles").delete().eq("user_id", user.id);
    if (profileError) throw new Error("تعذر حذف الملف الشخصي.");

    // Revoke refresh sessions before permanently deleting the Auth user.
    const { error: signOutError } = await admin.auth.admin.signOut(accessToken);
    if (signOutError) throw new Error("تعذر إنهاء جلسات الحساب بأمان.");

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw new Error("تعذر حذف حساب الدخول من الخادم.");

    return json({ success: true });
  } catch (error) {
    console.error("delete-account failed:", error instanceof Error ? error.message : "unknown error");
    return json({
      success: false,
      error: error instanceof Error ? error.message : "حدث خطأ أثناء حذف الحساب. حاول مرة ثانية.",
    }, 500);
  }
});
