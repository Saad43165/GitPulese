abstract class OAuthConstants {
  // Register at: github.com/settings/developers → OAuth Apps → New
  // Callback URL: gitpulse://oauth
  static const clientId = 'Ov23liSRrNr1PE6Kbd1F';
  static const clientSecret = '94650ead1d11166ffbdd173cb2b4135fac742cb3';
  
  static const callbackScheme = 'gitpulse';
  static const callbackUrl = 'gitpulse://oauth';
  static const scopes = 'repo user notifications gist read:org workflow';
  
  static const tokenEndpoint = 'https://github.com/login/oauth/access_token';
  static const authUrl = 'https://github.com/login/oauth/authorize';
}
