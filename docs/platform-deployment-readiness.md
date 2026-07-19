# Platform deployment hazirlik sozlesmesi

Bu sozlesme production deployment'inin D1/R2, Images, Queue ve Rate Limiting binding'lerini eksiksiz kurdugunu dogrulamak icindir. Hassas degerler, hesap kimlikleri, namespace degerleri ve tokenlar API cevabina veya bu dosyaya yazilmaz.

## Provision sirasi

1. Sites deployment'inda `.openai/hosting.json` kaynakli `DB` D1 ve `MEDIA` R2 binding'lerini olustur.
2. Ana responsive medya kuyrugunu ve ayri dead-letter kuyrugunu olustur.
3. Ayni Worker'a `MEDIA_DERIVATIVE_QUEUE` producer binding'ini ve ana kuyruk consumer'ini bagla.
4. Consumer icin baslangic politikasi olarak `max_batch_size=3`, `max_batch_timeout=5`, `max_retries=5`, `retry_delay=30` ve dead-letter queue tanimla. `max_concurrency` Images kota/gozlem sonucuna gore ayrica sinirlanir; tahminle sabitlenmez.
5. Worker'a `IMAGES` binding'ini bagla.
6. Hesaba ozgu pozitif tamsayi namespace ile `EDGE_RATE_LIMITER` binding'ini 120 istek / 60 saniye politikasinda bagla.
7. Hosted runtime degerlerini `MEDIA_DERIVATIVE_DISPATCH_MODE=cloudflare_queue` ve `RATE_LIMIT_MODE=cloudflare_hybrid` yap.

Queue consumer veya dead-letter politikasi runtime binding nesnesinden okunamaz. Bu nedenle uygulama otomatik olarak binding ve modlari kontrol eder; consumer/DLQ ayari deployment kaynaginda veya Cloudflare panelinde ayrica elle dogrulanir. DLQ tanimlanmazsa retry sinirina ulasan mesaj kalici olarak silinebilir.

## Guvenli readiness ucu

- Studio UI: `/qa`
- Admin-only JSON: `GET /api/admin/platform-readiness`
- Public host: 404
- Studio oturumu yok: 401
- Otomatik zorunlu kontrol eksik: 503
- Otomatik kontroller hazir: 200
- Tum cevaplar `private, no-store`

JSON yalniz profil, mod adlari, bilinen binding adlari ve boolean/durum bilgisi tasir. Binding nesnesi, hesap kimligi, queue adi, URL, token, secret veya ortam degeri donmez.

## Smoke testi

1. Test deployment'inda Studio `/qa` ekraninda profilin `Production` ve otomatik kontrollerin hazir oldugunu dogrula.
2. Admin oturumuyla readiness ucunun 200; public hosttan ayni path'in 404 dondugunu dogrula.
3. Queue consumer ve DLQ politikasini deployment kaynaginda kontrol edip `QA-OPS-01` kaydina ortam/tarih notu ekle.
4. `QA-MED-02` responsive varyant/idempotency testini ve `QA-SEC-01` edge + D1 fail-closed testini tamamla.
5. Queue veya edge binding'ini test ortaminda gecici kaldir; readiness ucu 503 donmeli ve ilgili mutation sessiz fallback yapmamali.

Repository'deki `.openai/hosting.json` yalniz Sites tarafindan desteklenen mantiksal D1/R2 bildirimlerini tasir. Queue, Images, rate-limit namespace veya hesap kaynak kimligi bu dosyaya tahminle eklenmez.
