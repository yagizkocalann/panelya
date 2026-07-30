# Auth0 canli web ve hesap yonetimi provisioning

Bu runbook, Panelya web BFF girisi ile ortak `/api/account/*` hesap
mutation'larini development tenantinda canli dogrulamak icindir. Degerler
yalniz Git disi `.dev.vars` veya deployment secret store alanina yazilir.
Client secret, token, authorization code, PKCE verifier, provider subject ve
test hesabi parolasi terminal ciktisina, dokumana veya Git'e girmez.

## 1. Panelya Web confidential uygulamasi

Auth0 Dashboard > Applications > Applications > Create Application:

- Ad: `Panelya Web`
- Tip: `Regular Web Applications`
- Ownership: first-party
- Token Endpoint Authentication Method: Client Secret Post
- OIDC Conformant: acik
- JWT signing: RS256
- Grant Types: yalniz Authorization Code
- Implicit, Password, Client Credentials ve MFA grant'leri: kapali

Development tenantinda yerel QA icin Allowed Callback URLs:

- `http://localhost:3000/api/auth/web/callback`
- `http://localhost:3000/account/reauthentication/callback`

Allowed Logout URLs:

- `http://localhost:3000`

Application Login URI:

- `http://localhost:3000/login`

Allowed Web Origins ve Allowed Origins (CORS) bos kalir. Panelya web girisi
server-side BFF akisi oldugu icin browser JavaScript'inin Auth0 API'ye
cross-origin istek atmasi gerekmez.

Production acilisinda localhost adresleri production uygulamasina tasinmaz.
Yalniz kontrol edilen HTTPS public origin kullanilir:

- `https://<public-domain>/api/auth/web/callback`
- `https://<public-domain>/account/reauthentication/callback`
- logout: `https://<public-domain>`
- login URI: `https://<public-domain>/login`

Wildcard, query, fragment ve gereksiz trailing slash kullanilmaz. Dashboard
allowlist'i ile `AUTH0_WEB_REDIRECT_URIS` ve `AUTH0_WEB_LOGOUT_URIS` exact ayni
olur.

## 2. Database ve Google connection

Authentication > Database > `Username-Password-Authentication` ve
Authentication > Social > Google connection uygulamanin Connections
sekmesinde yalniz gereken istemciler icin acilir:

- `Panelya Web`
- `Panelya Mobile`

Management M2M uygulamasi kullanici girisi yapmadigi icin bu connection'lara
baglanmaz. Google development keys yalniz yerel tenant denemesi icindir;
production SSO acilisindan once ayri Google OAuth istemcisi ve izin ekrani
provision edilir.

## 3. Panelya Account Management M2M

Applications > Applications > Create Application:

- Ad: `Panelya Account Management`
- Tip: `Machine to Machine Applications`
- API: tenantta hazir gelen `Auth0 Management API`

Yalniz su bes izin verilir:

- `read:users`
- `update:users`
- `delete:users`
- `read:device_credentials`
- `delete:device_credentials`

`create:client_grants`, `update:client_grants`, tenant ayarlari, connection
yonetimi, rol veya log izinleri verilmez. Management API tokeni sadece
server-side adapter tarafindan kullanilir ve istemci cevabina girmez.

## 4. Git disi runtime alanlari

`.dev.vars` icinde asagidaki alan adlari bulunur; bu dokumana deger yazilmaz:

- `AUTH0_GATEWAY_ENABLED`
- `AUTH0_ISSUER`
- `AUTH0_MOBILE_CLIENT_ID`
- `AUTH0_AUDIENCE`
- `AUTH0_MOBILE_REDIRECT_URIS`
- `AUTH0_WEB_CLIENT_ID`
- `AUTH0_WEB_CLIENT_SECRET`
- `AUTH0_WEB_REDIRECT_URIS`
- `AUTH0_WEB_LOGOUT_URIS`
- `AUTH0_MANAGEMENT_CLIENT_ID`
- `AUTH0_MANAGEMENT_CLIENT_SECRET`
- `AUTH0_MANAGEMENT_AUDIENCE`
- `AUTH0_DATABASE_CONNECTION`
- `ACCOUNT_RUNTIME_SECRET`

`ACCOUNT_RUNTIME_SECRET` en az 32 karakterlik kriptografik rastgele degerdir ve
Auth0 client secret ile ayni olamaz. Anahtar rotasyonu mevcut oturum ve
bekleyen reauthentication kanitlarini bilincli olarak gecersizlestirir.

## 5. Secretsiz on kontrol

Yerel canli turdan once:

```powershell
npm run auth0:preflight
```

Komut yalniz kontrol adini ve `OK`/`EKSİK` durumunu gosterir. Secret veya URI
degerini yazdirmaz. Tum kontroller `OK` olmadan canli mutation baslatilmaz.

## 6. Canli QA sirasi

Geri alinabilir akislardan baslanir:

1. `/login` database hesabi girisi ve `/account` acilisi.
2. Profil adi degisikligi.
3. Sifre yenileme e-postasi.
4. Ayrilmis ikinci e-posta ile e-posta degisikligi; `max_age=0` yeniden giris.
5. Web ve native oturum envanteri; once tekil, sonra `others` iptali.
6. Engel listesi ve engel kaldirma.
7. Google test hesabinda provider-managed satirlar; yerel sifre formu olmamali.
8. Yalniz disposable database hesabinda hesap silme.

Her destructive denemeden once test hesabinin disposable oldugu tekrar
dogrulanir. Hesap silme basarili oldugunda Auth0 kullanicisi, Panelya oturumlari
ve silme/anonimlestirme politikasi birlikte kontrol edilir. Gercek kullanici
hesabi bu turda kullanilmaz.

## 7. Tamamlama kaniti

- `npm run auth0:preflight`: basarili.
- `QA-AUTH-05` ve `QA-ACC-05`: tarih, cihaz/tarayici ve sonuc notuyla
  `docs/manual-qa-checklist.md` icinde guncellenmis.
- Auth0 tenant logunda beklenen login/Management API islemleri var; dokumana
  provider subject veya token kopyalanmamis.
- `.dev.vars` Git tarafindan izlenmiyor.
- Test bittiginde gecici hesap ve bekleyen reauthentication kaydi birakilmamis.

## Resmi kaynaklar

- Regular Web Application:
  <https://auth0.com/docs/get-started/auth0-overview/create-applications/regular-web-apps>
- Application callback/logout ayarlari:
  <https://auth0.com/docs/get-started/applications/application-settings>
- Machine-to-Machine uygulama:
  <https://auth0.com/docs/get-started/auth0-overview/create-applications/machine-to-machine-apps>
- Management API:
  <https://auth0.com/docs/api/management/v2>
- Device credential listeleme:
  <https://auth0.com/docs/api/management/v2/device-credentials/get-device-credentials>
- Device credential silme:
  <https://auth0.com/docs/api/management/v2/device-credentials/delete-device-credentials-by-id>
- Kullanici guncelleme:
  <https://auth0.com/docs/api/management/v2/users/patch-users-by-id>
- Client secret rotasyonu:
  <https://auth0.com/docs/get-started/applications/rotate-client-secret>
