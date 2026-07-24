# چت روم با Supabase

پلتفرم ارتباطات real-time با Supabase

## ویژگی‌ها

- ✅ چت متنی real-time
- ✅ voice chat با WebRTC
- ✅ اشتراک‌گذاری صفحه
- ✅ آپلود فایل (ZIP, تصویر, صدا)
- ✅ نقش‌ها (Owner, Admin, User)
- ✅ تم تاریک RTL
- ✅ **رایگان با Supabase!**

---

## راه‌اندازی

### قدم ۱: اکانت Supabase بساز

1. برو به [supabase.com](https://supabase.com)
2. با GitHub لاگین کن
3. **New Project** رو کلیک کن
4. تنظیمات:
   - **Name:** `messenger`
   - **Database Password:** یه رمز قوی
   - **Region:** انتخاب نزدیک‌ترین منطقه
5. **Create Project** رو کلیک کن

### قدم ۲: Schema رو اجرا کن

1. در Supabase Dashboard برو به **SQL Editor**
2. فایل `supabase/schema.sql` رو paste کن
3. **Run** رو کلیک کن

### قدم ۳: Storage Bucket بساز

1. در Dashboard برو به **Storage**
2. **New Bucket** رو کلیک کن
3. تنظیمات:
   - **Name:** `uploads`
   - **Public:** ✅ تیک بزن
4. **Create Bucket** رو کلیک کن

### قدم ۴: تنظیمات پروژه

1. در Dashboard برو به **Settings** > **API**
2. **Project URL** رو کپی کن
3. **anon public** key رو کپی کن

### قدم ۵: کد رو تنظیم کن

فایل `public/js/app.js` رو باز کن و خطوط زیر رو عوض کن:

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL'; // Project URL رو اینجا بذار
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'; // anon key رو اینجا بذار
```

مثال:
```javascript
const SUPABASE_URL = 'https://xyzcompany.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### قدم ۶: اجرا کن

```bash
# با هر سرور ساده‌ای
npx serve public
# یا
python -m http.server 3000 --directory public
```

مرورگر رو باز کن و برو به `http://localhost:3000`

---

## دیپلوی رایگان

### Vercel (ساده‌ترین)

1. کد روی GitHub آپلود کن
2. برو به [vercel.com](https://vercel.com)
3. با GitHub لاگین کن
4. **Import Project** > ریپازیتوری رو انتخاب کن
5. **Deploy** رو کلیک کن

### Netlify

1. کد روی GitHub آپلود کن
2. برو به [netlify.com](https://netlify.com)
3. **New site from Git** > GitHub رو انتخاب کن
4. **Deploy site** رو کلیک کن

---

## نکات امنیتی

- **SUPABASE_ANON_KEY** رو فقط در کد سمت کلاینت استفاده کن
- **service_role** key رو هیچوقت در کد سمت کلاینت نذار
- Row Level Security (RLS) رو همیشه فعال نگه دار

---

## ساختار پروژه

```
messenger-supabase/
├── public/
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── app.js
├── supabase/
│   └── schema.sql
└── README.md
```

---

## تکنولوژی‌ها

- **Frontend:** HTML, CSS, JavaScript
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime)
- **Voice/Screen:** WebRTC
- ** Hosting:** Vercel/Netlify (رایگان)
