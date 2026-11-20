# تشغيل المساعد الذكي

## إعداد Cloudflare Worker
اسم Worker الحالي في المشروع: `third-intermediate-ai`.
من مجلد `worker` شغّل:
```bash
npm install -g wrangler
wrangler login
wrangler secret put GEMINI_API_KEY
wrangler deploy
```
ألصق مفتاح Gemini عند طلبه. لا تضع المفتاح في ملفات Flutter أو GitHub أو داخل التطبيق.

## عنوان الخدمة
التطبيق يتصل بعنوان Worker الحالي:
`https://wispy-union-276e.dhwa634.workers.dev/chat`
إذا تغيّر اسم Worker أو النطاق، حدّث عنوان endpoint في `lib/main.dart` ثم أعد بناء التطبيق.

## بعد تعديل الخادم
أي commit في GitHub لا ينشر Worker تلقائياً. يجب تنفيذ `wrangler deploy` يدوياً من مجلد `worker` أو إعداد نشر آلي منفصل مع Cloudflare API Token محفوظ كـ Secret.

## النموذج والحدود
يستخدم الخادم `gemini-3.5-flash-lite`. راجع حدود الخطة المجانية والأسعار وسياسة الاحتفاظ بالبيانات في Google AI Studio قبل الإطلاق. لا توجد ضمانة لاستخدام مجاني غير محدود.

## الخصوصية والأمان
- مفتاح Gemini يبقى في Cloudflare Secret.
- لا يطلب التطبيق حساباً أو كلمة مرور.
- نص السؤال وسياق المحادثة يُرسلان إلى Worker ثم إلى Google Gemini لمعالجة الرد.
- لا ترسل بيانات شخصية أو كلمات مرور أو معلومات حساسة إلى المساعد.
- يجب تفعيل حدود طلبات ومراقبة الاستخدام في Cloudflare قبل فتح الخدمة للجمهور.
