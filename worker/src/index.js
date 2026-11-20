export default {
  async fetch(request, env) {
    const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Methods":"POST, OPTIONS","Access-Control-Allow-Headers":"Content-Type"};
    if (request.method === "OPTIONS") return new Response(null, {headers:cors});
    if (new URL(request.url).pathname !== "/chat") return Response.json({error:"Not found"},{status:404,headers:cors});
    if (request.method !== "POST") return Response.json({error:"Method not allowed"},{status:405,headers:cors});
    if (!env.GEMINI_API_KEY) return Response.json({error:"Server API key is not configured"},{status:503,headers:cors});
    try {
      const body = await request.json();
      const message = String(body.message || "").trim();
      if (!message || message.length > 12000) return Response.json({error:"Message is empty or too long"},{status:400,headers:cors});
      const upstream = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",{
        method:"POST",
        headers:{"Content-Type":"application/json","x-goog-api-key":env.GEMINI_API_KEY},
        body:JSON.stringify({
          systemInstruction:{parts:[{text:"أنت مساعد تعليمي عراقي لطلبة الثالث المتوسط. أجب باللغة العربية الواضحة القريبة من اللهجة العراقية عند الحاجة. اشرح المسائل خطوة بخطوة، واذكر القانون والتعويض والنتيجة، ولا تخترع معلومات أو تنسب سؤالاً إلى سنة وزارية دون دليل."}]},
          contents:[{role:"user",parts:[{text:message}]}],
          generationConfig:{temperature:0.5,maxOutputTokens:1800}
        })
      });
      const result = await upstream.json();
      if (!upstream.ok) return Response.json({error:result.error?.message || "Gemini request failed"},{status:502,headers:cors});
      const reply = result.candidates?.[0]?.content?.parts?.map(part=>part.text||"").join("").trim();
      if (!reply) return Response.json({error:"No response from Gemini"},{status:502,headers:cors});
      return Response.json({reply},{headers:cors});
    } catch (_) {
      return Response.json({error:"Invalid request or upstream error"},{status:500,headers:cors});
    }
  }
};
