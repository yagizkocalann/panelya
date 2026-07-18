# Reklam test plani

## Mevcut durum

- `home-feed-01`: ana akis icinde Google test reklam alani.
- `series-detail-01`: seri bilgisi ile bolum listesi arasinda Google test reklam alani.
- `/studio/ads`: test render durumu, reklam haritasi ve responsive kontrol listesi.
- Alanlar `data-ad-test-slot` ve `data-ad-status` ile otomatik testte bulunabilir.
- Google Publisher Tag yalniz `https://securepubads.g.doubleclick.net/tag/js/gpt.js` adresinden yuklenir.
- Resmi ornek birim `/6355419/Travel/Europe/France/Paris` ve sabit `300x250` boyutu kullanilir.
- Panelya publisher kimligi, gercek reklam kampanyasi, gelir, otomatik tiklama veya sahte etkilesim yoktur.
- Reklam engelleyici veya ag hatasinda sekiz saniye sonra aciklayici `blocked` durumu gorunur; sayfa akisi bozulmaz.

## Sonraki adim

Gercek entegrasyonda publisher ve slot kimlikleri environment secret olarak verilecek; gelistirme/test ortami resmi ornek agda kalacak. Reklam yuklenmese bile ayrilan 300x250 alan CLS olusturmayacak, okuyucu panelini kapatmayacak ve mobil dokunma kontrollerine girmeyecek.

## Resmi kaynaklar

- https://developers.google.com/publisher-tag/guides/get-started
- https://developers.google.com/publisher-tag/samples/display-test-ad
- https://support.google.com/adsense/answer/2660562
