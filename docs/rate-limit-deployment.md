# Production rate-limit operasyonu

Panelya iki katmanli koruma kullanir. D1 sayaci 15 dakika, 30 dakika, 1 saat ve 24 saatlik urun kotalarini atomik olarak kesin uygular. Cloudflare Rate Limiting binding'i production'da ayni scope/fingerprint anahtari icin ani trafik kalkanidir; lokasyon bazli ve yaklasik oldugu icin tek basina hesap guvenligi kotasi sayilmaz.

## Runtime modlari

- Yerel ve CI: `RATE_LIMIT_MODE=d1_strict`
- Production: `RATE_LIMIT_MODE=cloudflare_hybrid`
- Production binding: `EDGE_RATE_LIMITER`

Binding deployment Worker'inda 120 istek / 60 saniye basit politika ile, hesaba ozgu pozitif tamsayi `namespace_id` kullanilarak tanimlanir. Ayni namespace birden fazla Worker'da kullanilirsa ayni anahtar sayacini paylasir. Repository'deki `.openai/hosting.json` Sites'in D1/R2 bildirimlerini tasir; desteklenmeyen rate-limit binding'i veya hesap namespace kimligi bu dosyaya tahminle eklenmez.

## Fail-closed ve veri siniri

Cloudflare hibrit modu seciliyken binding yoksa, bilinmeyen mod girilirse veya limit servisi hata verirse korunan mutation reddedilir. Edge anahtarinda yalniz scope ve SHA-256 fingerprint bulunur; e-posta, IP, user id, parola, token veya cookie ham olarak binding'e gonderilmez.

## Smoke testi

1. Test deployment'inda `EDGE_RATE_LIMITER` binding'ini ve `cloudflare_hybrid` modunu etkinlestir.
2. Studio `/qa` ekraninda `Cloudflare edge ani trafik kalkani + atomik D1 kesin kota` etiketini dogrula.
3. Ayrilmis sentetik hesapla login/register/reset kotalarini test et; hata mesaji hesap varligini aciklamamali.
4. Eszamanli sentetik isteklerde kabul edilen toplam istek ilgili D1 kotasini asmamali.
5. Binding'i gecici kaldir; Studio `/qa` yapilandirma hatasi gostermeli ve korunan mutation fail-closed reddedilmeli.
6. Modu `d1_strict` yap; yerel/CI davranisi binding olmadan atomik D1 kotasiyla devam etmeli.

Sonuc `docs/manual-qa-checklist.md` icindeki `QA-SEC-01` ve `QA-ACC-05` kayitlarina tarih/notla yazilir.

Tum platform binding'leri birlikte `docs/platform-deployment-readiness.md` sirasiyla provision edilir. Studio `/qa` ile admin-only `/api/admin/platform-readiness` edge binding'inin varligini degerlerini aciklamadan kontrol eder.
