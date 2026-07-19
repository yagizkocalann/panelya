# Reklam test plani

## Mevcut durum

- `home-feed-01`: ana akis icinde Google test reklam alani.
- `series-detail-01`: seri bilgisi ile bolum listesi arasinda Google test reklam alani.
- `/studio/ads`: test render durumu, reklam haritasi ve responsive kontrol listesi.
- Alanlar `data-ad-test-slot` ve `data-ad-status` ile otomatik testte bulunabilir.
- Ilk ziyarette reklam izni secilene kadar `consent_required`; yalniz gerekli secildiginde `consent_denied` durumu gorunur ve Google istegi yapilmaz.
- Google Publisher Tag, yalniz acik reklam izninden sonra ve sadece localhost/loopback hostunda `https://securepubads.g.doubleclick.net/tag/js/gpt.js` adresinden yuklenir.
- Resmi ornek birim `/6355419/Travel/Europe/France/Paris` ve sabit `300x250` boyutu kullanilir.
- Panelya publisher kimligi, gercek reklam kampanyasi, gelir, otomatik tiklama veya sahte etkilesim yoktur.
- Reklam engelleyici veya ag hatasinda sekiz saniye sonra aciklayici `blocked` durumu gorunur; sayfa akisi bozulmaz.
- Tercih `panelya-consent-v1` anahtariyla yalniz cihazda tutulur; footer veya `/privacy` uzerinden yeniden acilir. Reklam izni geri cekildiginde sayfa yeniden yuklenerek yuklenmis GPT oturumu temizlenir.

## Ortam siniri

- `AD_RUNTIME_MODE=google_test`: yalniz `localhost`, `*.localhost`, `127.0.0.1` ve `::1` uzerinde resmi test birimini etkinlestirir.
- `AD_RUNTIME_MODE=disabled`: reklam alanini ve harici istegi kapatir.
- Deger yoksa yerel hostlarda `google_test`, diger hostlarda `disabled` uygulanir.
- `production`, bilinmeyen deger veya localhost disinda `google_test` fail-closed olarak `disabled` olur. Gercek publisher/slot degerleri bu surumde kod veya environment sinirina baglanmamistir.

## Sonraki adim

Gercek entegrasyondan once production CMP/provider secimi, hukuki metin ve bolgesel onay sinyali ayri bir karar olarak tamamlanacak. Publisher/slot yapilandirmasi test biriminden ayri tutulacak. Reklam yuklenmese bile ayrilan 300x250 alan CLS olusturmayacak, okuyucu panelini kapatmayacak ve mobil dokunma kontrollerine girmeyecek.

## Resmi kaynaklar

- https://developers.google.com/publisher-tag/guides/get-started
- https://developers.google.com/publisher-tag/samples/display-test-ad
- https://support.google.com/adsense/answer/2660562
