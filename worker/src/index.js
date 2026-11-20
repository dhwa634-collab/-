const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Cache-Control": "no-store",
};

function json(data, status = 200) {
  return Response.json(data, { status, headers: corsHeaders });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (url.pathname !== "/chat") return json({ error: "Not found" }, 404);
    if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
    if (!env.GEMINI_API_KEY) {
      return json({ error: "مفتاح المساعد غير مضبوط على الخادم." }, 503);
    }

    try {
      const body = await request.json();
      const message = String(body.message || "").trim();
      if (!message) return json({ error: "اكتب سؤالك أولاً." }, 400);
      if (message.length > 8000) {
        return json({ error: "السؤال طويل جداً. اختصره وحاول مرة ثانية." }, 413);
      }

      const history = Array.isArray(body.history) ? body.history.slice(-10) : [];
      const contents = [];
      for (const item of history) {
        if (!item || typeof item !== "object") continue;
        const role = item.role === "assistant" || item.role === "model"
          ? "model"
          : item.role === "user" ? "user" : null;
        const text = String(item.text || "").trim().slice(0, 3000);
        if (role && text) contents.push({ role, parts: [{ text }] });
      }
      contents.push({ role: "user", parts: [{ text: message }] });

      const upstream = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": env.GEMINI_API_KEY,
          },
          signal: AbortSignal.timeout(45000),
          body: JSON.stringify({
            systemInstruction: {
              parts: [{
                text: "أنت مساعد تعليمي عراقي لطلبة الثالث المتوسط. أجب باللغة العربية الواضحة القريبة من اللهجة العراقية عند الحاجة. افهم سياق المحادثة وأسئلة المتابعة. اشرح المسائل خطوة بخطوة، واذكر القانون والتعويض والوحدات والنتيجة. إذا كان السؤال ناقص المعطيات فاطلب توضيحاً ولا تخمّن. لا تنسب سؤالاً إلى سنة وزارية دون دليل. إذا اكتشفت خطأ في إجابة سابقة فصححه بوضوح.",
              }],
            },
            contents,
            generationConfig: { temperature: 0.35, maxOutputTokens: 2200 },
          }),
        },
      );

      let result;
      try {
        result = await upstream.json();
      } catch {
        return json({ error: "تعذر قراءة رد خدمة الذكاء الاصطناعي." }, 502);
      }
      if (!upstream.ok) {
        const safeMessage = upstream.status === 429
          ? "وصل المساعد إلى حد الطلبات المؤقت. انتظر قليلاً ثم حاول."
          : upstream.status === 400
            ? "تعذر فهم الطلب. أعد صياغة السؤال وجرب."
            : "خدمة الذكاء الاصطناعي لم تستجب حالياً. حاول بعد قليل.";
        return json({ error: safeMessage, code: upstream.status }, 502);
      }

      const candidate = result.candidates?.[0];
      const reply = candidate?.content?.parts
        ?.map((part) => part.text || "").join("").trim();
      if (!reply) {
        return json({
          error: candidate?.finishReason === "SAFETY"
            ? "ما أگدر أجاوب على هالطلب. غيّر صياغة السؤال الدراسي."
            : "ما وصل رد واضح من المساعد. جرّب مرة ثانية.",
        }, 502);
      }
      return json({ reply });
    } catch (error) {
      if (error?.name === "TimeoutError" || error?.name === "AbortError") {
        return json({ error: "تأخر الرد. جرّب مرة ثانية بعد قليل." }, 504);
      }
      return json({ error: "صار خطأ مؤقت أثناء معالجة السؤال." }, 500);
    }
  },
};
