# Üretim notları

- Kaynak kural: `webtoon-kural-kitabi.md` v1.
- Use case: `illustration-story`.
- Önceki `Yarınki Ses` görselleri referans olarak kullanılmaz.
- Bu paket bağımsız stil karşılaştırmasıdır; kullanıcı onayı olmadan kataloğa veya Production Bible'ın kabul edilmiş stiline taşınmaz.
- Varsayılan lettering yöntemi 7.A: bütün görseller metinsiz üretilir, Türkçe metin daha sonra kod overlay olur.
- Kaynak referans sitenin hiçbir görseli üretim girdisi değildir.
- Built-in image generation kullanıldı; CLI/API fallback kullanılmadı.
- Kabul paketi: iki karakter için 6 sheet + beş S01 paneli. Her kabul PNG'sinin metadata-clean kardeşi vardır.
- 690 px akış ve kod overlay örneği `bolum-01/strip/preview.html` içindedir.
- Metinsiz mekanik şerit kontrolü `bolum-01/strip/bolum-01-style-master-preview.webp` olarak 690 × 5470 px üretildi.
- Beş panellik ilk stil QA sonucu `qa.md` içinde 91/100'dür; bu sonuç tam bölüm üretim izni değildir.
- Kural kitabı v1.1 arka plan düzeltmesi için 12 panellik ikinci tur `style-master-v2/` altında üretildi.
- V2, kabul edilmiş karakter sheet'lerine dokunmadan E/N/B/C arka plan register'larını test eder.
- V2 görsel QA sonucu `qa-v2.md` içinde 92/100'dür; kullanıcı style-master onayı beklenir ve bu nedenle kataloğa eklenmemiştir.
- V2 kabul panellerinin metadata-clean PNG kardeşleri, temas sayfası ve 690 px dikey şerit önizlemesi vardır.
