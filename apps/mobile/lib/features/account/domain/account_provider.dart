/// Kullanıcının Auth0'a hangi kimlik sağlayıcısıyla (connection) giriş
/// yaptığı.
///
/// PROVISIONAL: ADR-047 kapsamının ("Hesabım" ekranları) bir parçası olarak
/// tanımlandı, ama web tarafının henüz `main`e girmemiş gerçek
/// `/api/account/*` sözleşmesinde (JSON Schema/OpenAPI/fixture) bu bilginin
/// tam şekli/ismi netleşmedi. Bu enum yalnız bir YER TUTUCUdur — gerçek
/// capability sözleşmesi geldiğinde (bkz. `AccountProviderX` altındaki
/// gerekçe) tamamen değiştirilmesi/kaldırılması beklenir. `AuthUser`
/// (üretilen DTO, bkz. `core/contracts/generated/auth_user.dart`) BU ALANI
/// TAŞIMAZ — burada ayrı, elle yazılmış bir tip olarak tutulur.
enum AccountProvider {
  /// Auth0 Database connection: e-posta + şifre. Panelya'nın kendi
  /// e-posta değiştirme/şifre sıfırlama akışları yalnız bu sağlayıcıda
  /// anlamlıdır.
  database,

  /// Google sosyal girişi. Şifre ve e-posta Google tarafından yönetilir;
  /// Panelya uygulama içi bir şifre/e-posta değiştirme formu GÖSTERMEZ.
  google,
}

/// [AccountProvider]'a göre "E-posta ve şifre" ekranında hangi aksiyonların
/// gösterileceğini belirler (bkz. `security_screen.dart`).
///
/// PROVISIONAL: gerçek capability sözleşmesi geldiğinde sağlayıcıya göre
/// aksiyon gösterme/gizleme kararı SUNUCUDAN gelen bir capability
/// payload'una taşınacak; bu extension o zamana kadarki yerel yer
/// tutucudur.
extension AccountProviderX on AccountProvider {
  bool get supportsEmailChange => this == AccountProvider.database;

  bool get supportsPasswordReset => this == AccountProvider.database;
}
