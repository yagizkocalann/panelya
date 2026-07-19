# Production auth ve oturum sozlesmesi (ADR-039)

## Karar

Production okuyucu kimligi icin yonetilen saglayici olarak Auth0 secildi. Web ve Flutter ayni Panelya kullanicisini gorur fakat ayni kimlik bilgisini saklama teknigini kullanmaz:

- Flutter, sistem tarayicisinda OAuth 2.0 Authorization Code + PKCE (`S256`) baslatir. Embedded WebView ve uygulamaya gomulu client secret kullanilmaz.
- Mobil token degisimi Panelya'nin `/api/auth/mobile/token` gateway'i uzerinden yapilir. Gateway public native client olarak Auth0'ya PKCE verifier ile gider; client secret gerektirmez ve tokenlari kalici olarak saklamaz.
- Access token 15 dakika yasayan Panelya API audience tokenidir. Flutter bunu yalniz isletim sistemi secure storage katmaninda tutar ve API'ye `Authorization: Bearer` ile gonderir.
- Refresh token doner, 30 gunluk mutlak omurle sinirlidir ve her kullanimda yenilenir. Mobil istemci yeni refresh tokeni atomik olarak yazmadan eskisini silmez; reuse algilanirsa tum token ailesi iptal edilir ve yeniden giris gerekir.
- Web, Auth0 callback'inden sonra mevcut host-only `HttpOnly`, `Secure`, `SameSite=Lax` Panelya session cookie'sini kullanir. Provider tokeni tarayici JavaScript'ine veya `localStorage`'a verilmez. Public ve Studio cookie kapsamlari ayri kalir.
- API, mobil access tokenini JWKS ile; issuer, audience, algoritma, sure ve scope kontrolleriyle dogrular. ID token API yetkilendirmesinde kabul edilmez.
- Panelya `reader`/`admin` rolu D1'de kalir. Token claim'i tek basina Studio yetkisi vermez; her admin istegi sunucu tarafinda guncel yerel rolu yeniden kontrol eder.

## Neden Auth0

Auth0'nun resmi Flutter SDK'si native Web Authentication ve secure Credentials Manager saglar. Authorization Code + PKCE, `offline_access`, expiring refresh-token rotation ve reuse detection resmi olarak desteklenir. Standart OIDC/JWKS siniri sayesinde Cloudflare Worker tarafinda vendor SDK'si zorunlu degildir.

Clerk public-client PKCE sunar; ancak Temmuz 2026 dokumantasyonunda custom OAuth scopes gelistirme asamasindadir ve varsayilan OAuth refresh tokenlari suresizdir. Panelya'nin kisa erisim tokeni, sinirli refresh omru ve ayrik API scope gereksinimleri icin Auth0 daha net bir uyum saglar.

Resmi kaynaklar:

- https://auth0.com/docs/quickstart/native/flutter
- https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/authorize-with-pkce
- https://auth0.com/docs/secure/tokens/refresh-tokens/configure-refresh-token-rotation
- https://auth0.com/docs/secure/tokens/access-tokens/validate-access-tokens

## Ortak istemci sozlesmesi

Tek kaynak `packages/contracts/schema.json`, HTTP eslemesi `packages/contracts/openapi.json` olur.

| Islem | Endpoint | Davranis |
| --- | --- | --- |
| Public konfigurasyon | `GET /api/auth/config` | Issuer, public client id, audience, scope ve endpointleri dondurur; secret dondurmez. |
| Ilk mobil oturum | `POST /api/auth/mobile/token` | Authorization code + PKCE verifier'i degistirir; kisa access ve donen refresh tokeni verir. |
| Mobil yenileme | `POST /api/auth/mobile/token` | `grantType=refresh_token`; yeni access + yeni refresh tokeni verir. |
| Mobil iptal | `POST /api/auth/mobile/revoke` | Refresh grantini iptal eder; ayni istegin tekrarini basarili kabul eder. |
| Kullanici ozeti | `GET /api/auth/me` | Web cookie veya mobil bearer tokenindan Panelya kullanicisini dondurur. |

Fixture tokenlari sentetiktir, `.example`/`.test` alan adlari kullanir ve hicbir ortamda gecerli degildir.

## Oturum ve hata kurallari

- Access token omru: 900 saniye.
- Refresh token mutlak omru: 30 gun; idle omru en cok 7 gun olarak provider tarafinda ayarlanir.
- Refresh retry cakismasi icin provider overlap/leeway en fazla 5 saniye olur.
- Logout/revoke refresh grantini kapatir; mevcut JWT access tokeni en gec 15 dakika icinde sona erer. Hassas Studio islemleri yine yakin zamanda kimlik dogrulama ve guncel D1 rol kontrolu ister.
- `token_reused`, `session_revoked`, `token_expired` ve `login_required` istemciyi secure storage'i temizleyip tekrar login'e goturur.
- `rate_limited` yalniz `retryAfterSeconds` sonrasinda yeniden denenir; sonsuz otomatik retry yapilmaz.
- Token, authorization code, verifier ve provider subject log/audit/analytics olayina yazilmaz.

## Hesap esleme ve gecis

- Auth0 `sub` degeri public API'ye acilmaz; D1'de ayrik provider identity eslemesine baglanir.
- Yeni production kullanicisi ilk basarili OIDC girisinde `reader` roluyle olusur.
- Mevcut yerel hesap yalniz kullanici mevcut yerel oturumunu yeniden dogrularken Auth0 girisini de tamamladiginda baglanir. Sadece ayni e-posta metnine bakarak sessiz hesap birlestirme yapilmaz.
- Yerel PBKDF2 parola, reset ve dogrulama akislari localhost QA icin kalir; production kimlik kaynagi sayilmaz.
- Studio production girisi Auth0 + yerel admin rolu ister. Adminler icin MFA ve hassas islemlerde yeniden kimlik dogrulama production tenant acilis kapisidir.

## Uygulama sirasi

1. Bu ADR ve ortak schema/OpenAPI/fixture'lar `main` dalina girer.
2. Auth0 tenant, custom domain, API audience, native/web callback ve logout URI'lari olusturulur.
3. Web gateway, JWKS dogrulama, provider identity D1 migration'i ve Auth0 callback'i ayri runtime PR'inda uygulanir.
4. Flutter ortak fixture'lari parse eder, Auth0 native Web Authentication ve secure credential storage adapter'ini ekler.
5. Web ve mobil gercek tenant smoke testleri gecmeden local auth production'da kapatilmaz.

## Kalan deployment kapilari

- Auth0 tenant ve custom domain henuz provision edilmedi.
- Production callback/deep-link alan adlari kesin deployment domainiyle kaydedilmelidir.
- Admin MFA, breach protection, bot/rate-limit ve e-posta sender ayarlari tenant acilisinda manuel dogrulanmalidir.
- Runtime token gateway ve JWKS dogrulama bu sozlesme PR'inin degil, izleyen production auth entegrasyon PR'inin kapsamidir.
