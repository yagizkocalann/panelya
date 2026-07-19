# Responsive medya worker operasyonu

Bu dokuman Queue kaynagi production ortaminda provision edilirken uygulanacak operasyon sozlesmesidir. Yerel varsayilan `MEDIA_DERIVATIVE_DISPATCH_MODE=local_browser` olarak kalir; servis hazir olmadan production modu acilmaz.

## Runtime binding'leri

- D1: `DB`
- Kaynak ve turetilmis nesneler icin R2: `MEDIA`
- Queue producer: `MEDIA_DERIVATIVE_QUEUE`
- Mod: `MEDIA_DERIVATIVE_DISPATCH_MODE=cloudflare_queue`
- Consumer: `worker/index.ts` icindeki `queue()` handler'i

Cloudflare Queue producer ve consumer baglantisi deployment platformunda yapilir. Queue tek aktif consumer kullanir; retry siniri ve dead-letter queue ayrica tanimlanir. Repository'deki `.openai/hosting.json` yalniz Sites'in destekledigi D1/R2 mantiksal binding'lerini tutar, Queue adini veya hesap kimligini tahminle icine almaz.

## Mesaj ve guvenlik

V1 mesaj yalniz `version`, `jobId`, `assetId`, `targetWidth`, `targetHeight` ve `format=webp` alanlarini tasir. Storage key, URL, e-posta, kullanici kimligi, cookie, bearer token veya secret kuyruga yazilmaz. Consumer gercek kaynak anahtarini D1'den yeniden cozer ve gorevin is kaydiyla tam eslestigini dogrular.

## Kabul smoke testi

1. Test ortamina Queue producer/consumer, D1, R2 ve Images binding'lerini bagla.
2. Studio `/media` uzerinden 1201 px veya daha genis ozgun bir test gorseli yukle.
3. Studio'da islemcinin `Cloudflare uretim kuyrugu` oldugunu ve uc isin teslim edildigini dogrula.
4. Worker tamamlandiginda 480/768/1200 varyantlarinin tekil oldugunu ve okuyucunun `srcset` uzerinden uygun olani alabildigini dogrula.
5. Ayni mesaji tekrar gonder; yeni bir `media_variants` satiri veya farkli kopya olusmamali.
6. Queue binding'ini test ortaminda gecici kaldir; yeni yuklemenin teslim hatasi gosterdigini ve sessizce yerel isleyiciye dusmedigini dogrula.
7. Binding'i geri getirip `Yeniden gonder` aksiyonunu calistir; is tamamlanmali ve audit'te yalniz kimlik/sayisal metadata bulunmali.

Bu test `docs/manual-qa-checklist.md` icindeki `QA-MED-02` ve `QA-STU-07` kayitlariyla birlikte kapatilir.
