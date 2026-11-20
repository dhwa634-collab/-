# تشغيل المساعد الذكي

## 1) إنشاء Worker
1. أنشئ حساباً في Cloudflare وافتح Workers & Pages.
2. من جهازك ثبّت Node.js ثم شغّل:
   `npm install -g wrangler`
3. سجّل الدخول:
   `wrangler login`
4. ادخل مجلد `worker` داخل هذا المشروع وشغّل:
   `wrangler deploy`

## 2) وضع مفتاح Gemini بأمان
من داخل مجلد `worker` شغّل:
`wrangler secret put GEMINI_API_KEY`
ألصق مفتاح Gemini الجديد في الطرفية عند الطلب. لا تضعه في ملفات المشروع أو GitHub أو تطبيق Flutter.

## 3) ربط التطبيق بعنوان Worker
بعد النشر سيظهر عنوان شبيه بـ:
`https://third-intermediate-ai.<your-account>.workers.dev`
افتح `lib/main.dart` وابحث عن:
`https://YOUR-WORKER-NAME.workers.dev/chat`
واستبدله بعنوان Worker الحقيقي مع إضافة `/chat` في النهاية.

## 4) بناء التطبيق
من جذر مشروع Flutter شغّل:
`flutter pub get`
ثم:
`flutter build apk --release`

## ملاحظات
- يستخدم الخادم نموذج `gemini-3.5-flash-lite`؛ راجع صفحة الأسعار وحدود الخطة المجانية في Google AI Studio قبل الإطلاق.
- لا يوجد مفتاح API داخل Flutter أو ملفات Git.
- واجهة المساعد لن تتصل فعلياً قبل نشر Worker ووضع المفتاح وإدخال عنوانه في التطبيق.
