# Google Play listing and App content answers (v1.0.0)

Everything to paste into Play Console for the first release. Graphics are in
the owner's `~/Desktop/Sale Lagi Hai - Play Store/` folder (made from the
real app on an emulator): `app-icon-512.png`, `feature-graphic-1024x500.png`
and six phone screenshots (1080 × 2160).

## Create the app
- App name: **Sale Lagi Hai!**
- Default language: **English (United States) – en-US**; add **Urdu – ur** as a translation.
- App or game: **App**. Free or paid: **Free**.

## Store settings
- Category: **Shopping**. Tags: Shopping, Coupons, Deals.
- Contact details: the email Play shows to users (required). Website: optional.
- Countries (Test and release, Production, Countries / regions): **Pakistan**.

## Main store listing, English
**Short description** (max 80):
> Every sale in Pakistan in one place: brand sales, bank card offers, bundles.

**Full description:**
> Sale Lagi Hai! brings every sale in Pakistan to one place, so you never miss a deal.
>
> • Brand sales in fashion, food and more: what's on, what ends soon, and where to use it.
> • Bank card offers: discounts with the cards you already have. We never ask for card numbers.
> • Mobile network bundles, side by side.
> • Deals near you: pick your city or use your approximate location. All of Pakistan is covered.
> • Save deals for later and follow your favourite brands.
> • Share any deal on WhatsApp in one tap.
> • English and Urdu, light and dark mode.
>
> Every deal shows when it was last checked, with a link to the original offer.
>
> Privacy first: no account needed, your data is never sold, and your location is used only for the search you ask for.

## Main store listing, Urdu (ur)
**Short description:**
> پاکستان کی ہر سیل ایک جگہ: برانڈ سیلز، بینک کارڈ آفرز اور موبائل بنڈلز۔

**Full description:**
> سیل لگی ہے! پاکستان کی ہر سیل ایک جگہ لاتی ہے، تاکہ آپ سے کوئی ڈیل نہ چھوٹے۔
>
> • فیشن، کھانے اور مزید برانڈز کی سیلز: کیا چل رہا ہے، کیا جلد ختم ہو رہا ہے، اور کہاں استعمال کریں۔
> • بینک کارڈ آفرز: اُن کارڈز پر رعایتیں جو آپ کے پاس پہلے سے ہیں۔ ہم کبھی کارڈ نمبر نہیں مانگتے۔
> • موبائل نیٹ ورکس کے بنڈلز، ایک ساتھ۔
> • آپ کے قریب ڈیلز: اپنا شہر چنیں یا اپنا اندازاً مقام استعمال کریں۔ پورا پاکستان شامل ہے۔
> • ڈیلز بعد کے لیے محفوظ کریں اور اپنے پسندیدہ برانڈز فالو کریں۔
> • کوئی بھی ڈیل ایک ٹیپ میں واٹس ایپ پر شیئر کریں۔
> • اردو اور انگریزی، لائٹ اور ڈارک موڈ۔
>
> ہر ڈیل پر لکھا ہوتا ہے کہ آخری بار کب جانچی گئی، اور اصل آفر کا لنک بھی۔
>
> آپ کی پرائیویسی پہلے: اکاؤنٹ کی ضرورت نہیں، آپ کا ڈیٹا کبھی بیچا نہیں جاتا، اور آپ کا مقام صرف اُسی تلاش کے لیے استعمال ہوتا ہے جو آپ کریں۔

## Release notes (1.0.0)
- en-US: `First release: every sale in Pakistan in one place.`
- ur: `پہلا ورژن: پاکستان کی ہر سیل ایک جگہ۔`

## App content (Policy and programs, App content)
- **Privacy policy:** `https://github.com/samcodes1/sale-lagi-hai/blob/main/assets/legal/privacy_en.txt` (public; the same text is in the app under Settings, Privacy policy).
- **App access:** All functionality is available without any access restrictions (v1 has no sign-in).
- **Ads:** Yes, the app contains ads.
- **Content rating** (IARC questionnaire): category **All Other App Types**. Answer **No** to violence, fear, sexuality, language, controlled substances, crude humour, gambling and simulated gambling. Users interact or communicate with each other: **No**. Shares the user's current location with other users: **No**. Allows purchases of digital goods: **No**. Expected rating: Everyone / PEGI 3.
- **Target audience and content:** **18 and over** only (bank card offers and ads; it also keeps the app out of the Families policy). Appeals to children: **No**.
- **News app:** No. **COVID-19 tracing:** No. **Government app:** No.
- **Financial features:** "My app doesn't provide any financial features" (it lists offers; no banking, loans or payments).
- **Health apps:** None.
- **Advertising ID:** Yes, used for **Advertising or marketing** (Google AdMob). The manifest declares `com.google.android.gms.permission.AD_ID`.

### Data safety
- Does the app collect or share any of the required user data types? **Yes**.
- Is all data encrypted in transit? **Yes** (HTTPS only).
- Do you provide a way for users to request that their data is deleted? **Yes** (v1 keeps nothing on the server about a guest; Settings, Privacy clears the phone).

| Data type | Collected | Shared | Ephemeral | Required? | Purposes |
|---|---|---|---|---|---|
| Location, Approximate location | Yes | Yes (Google AdMob infers it from the IP address) | Yes, for Near me | Optional | App functionality; Advertising or marketing |
| Device or other IDs (advertising ID) | Yes | Yes (Google AdMob) | No | Required | Advertising or marketing; Analytics; Fraud prevention, security and compliance |
| App activity, App interactions | Yes | Yes (Google AdMob, ad interactions) | No | Required | Advertising or marketing; Analytics |
| App info and performance, Diagnostics | Yes | Yes (Google AdMob) | No | Required | Analytics; Fraud prevention, security and compliance |

Not collected in v1: name, email, phone number (sign-in is off), financial info (card numbers are never asked; "My cards" keeps only bank and card type on the phone), messages, photos, contacts, precise location, web history.

When sign-in or push alerts are turned on in an update, add: Personal info, Phone number (Account management), and Device or other IDs for the push token (App functionality).

## Publishing path
- **New personal developer account** (created after 13 November 2023): run a **closed test** with at least **12 testers opted in for 14 days in a row**, then apply for production access (Dashboard). Start with Internal testing to check the build, then Closed testing.
- **Organization account:** after review, release to **Production** directly.
