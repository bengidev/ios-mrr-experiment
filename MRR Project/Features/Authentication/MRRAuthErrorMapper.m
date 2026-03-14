#import "MRRAuthErrorMapper.h"

#import "MRRAuthenticationController.h"

@import FirebaseAuth;

@implementation MRRAuthErrorMapper

// FirebaseAuth's Swift package surfaces these codes reliably on NSError even when the ObjC enum
// symbols are not exported cleanly into this target.
static NSInteger const MRRFirebaseAuthErrorCodeUserDisabled = 17005;
static NSInteger const MRRFirebaseAuthErrorCodeEmailAlreadyInUse = 17007;
static NSInteger const MRRFirebaseAuthErrorCodeInvalidEmail = 17008;
static NSInteger const MRRFirebaseAuthErrorCodeWrongPassword = 17009;
static NSInteger const MRRFirebaseAuthErrorCodeUserNotFound = 17011;
static NSInteger const MRRFirebaseAuthErrorCodeNetworkError = 17020;
static NSInteger const MRRFirebaseAuthErrorCodeWeakPassword = 17026;

+ (NSString *)titleForError:(NSError *)error {
  if ([error.domain isEqualToString:MRRAuthenticationErrorDomain]) {
    if (error.code == MRRAuthenticationErrorCodeRequiresAccountLinking) {
      return @"Link Existing Account";
    }

    if (error.code == MRRAuthenticationErrorCodeUnconfigured ||
        error.code == MRRAuthenticationErrorCodeMissingGoogleClientID ||
        error.code == MRRAuthenticationErrorCodeMissingGoogleCallbackScheme) {
      return @"Auth Setup Needed";
    }
  }

  if ([error.domain isEqualToString:FIRAuthErrorDomain]) {
    switch (error.code) {
      case MRRFirebaseAuthErrorCodeEmailAlreadyInUse:
        return @"Email Already Used";
      case MRRFirebaseAuthErrorCodeWeakPassword:
        return @"Password Too Weak";
      case MRRFirebaseAuthErrorCodeWrongPassword:
      case MRRFirebaseAuthErrorCodeUserNotFound:
        return @"Sign In Failed";
      default:
        break;
    }
  }

  return @"Authentication Failed";
}

+ (NSString *)messageForError:(NSError *)error {
  if ([error.domain isEqualToString:MRRAuthenticationErrorDomain]) {
    switch ((MRRAuthenticationErrorCode)error.code) {
      case MRRAuthenticationErrorCodeUnconfigured:
        return @"Firebase belum dikonfigurasi. Tambahkan GoogleService-Info.plist ke target app lalu aktifkan Email/Password dan Google di Firebase Authentication.";
      case MRRAuthenticationErrorCodeMissingGoogleClientID:
        return @"Client ID Google belum tersedia. Pastikan GoogleService-Info.plist sudah ada dan Firebase berhasil dikonfigurasi.";
      case MRRAuthenticationErrorCodeMissingGoogleCallbackScheme:
        return @"URL scheme Google Sign-In belum terpasang di Info.plist. Tambahkan REVERSED_CLIENT_ID dari GoogleService-Info.plist ke CFBundleURLTypes.";
      case MRRAuthenticationErrorCodeMissingGoogleToken:
        return @"Google Sign-In selesai, tetapi token autentikasi belum tersedia. Coba lagi setelah konfigurasi OAuth diperiksa.";
      case MRRAuthenticationErrorCodeRequiresAccountLinking:
        return @"Email ini sudah terdaftar dengan metode lain. Sign in dengan email dan password untuk menautkan akun Google Anda.";
      case MRRAuthenticationErrorCodeCancelled:
        return @"";
      case MRRAuthenticationErrorCodeNoCurrentSession:
        return @"Tidak ada sesi aktif yang bisa dipakai untuk menyelesaikan proses autentikasi.";
    }
  }

  if ([error.domain isEqualToString:FIRAuthErrorDomain]) {
    switch (error.code) {
      case MRRFirebaseAuthErrorCodeInvalidEmail:
        return @"Masukkan alamat email yang valid.";
      case MRRFirebaseAuthErrorCodeEmailAlreadyInUse:
        return @"Email ini sudah dipakai. Coba Sign In atau pakai email lain.";
      case MRRFirebaseAuthErrorCodeWeakPassword:
        return @"Gunakan password minimal 6 karakter agar akun bisa dibuat.";
      case MRRFirebaseAuthErrorCodeWrongPassword:
        return @"Password yang Anda masukkan belum cocok.";
      case MRRFirebaseAuthErrorCodeUserNotFound:
        return @"Akun dengan email ini belum ditemukan.";
      case MRRFirebaseAuthErrorCodeNetworkError:
        return @"Koneksi jaringan sedang bermasalah. Coba lagi sebentar lagi.";
      case MRRFirebaseAuthErrorCodeUserDisabled:
        return @"Akun ini sedang tidak bisa digunakan.";
      default:
        break;
    }
  }

  if (error.localizedDescription.length > 0) {
    return error.localizedDescription;
  }

  return @"Terjadi masalah saat memproses autentikasi. Coba lagi.";
}

@end
