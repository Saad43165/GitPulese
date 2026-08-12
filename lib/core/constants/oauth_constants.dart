abstract class OAuthConstants {
  // Register at: github.com/settings/developers → OAuth Apps → New
  // Callback URL: gitpulse://oauth
  static const clientId = 'Ov23liSRrNr1PE6Kbd1F';
  // NOTE: clientSecret has been moved securely to Cloudflare Worker. Do not add it here.
  
  static const callbackScheme = 'gitpulse';
  static const callbackUrl = 'gitpulse://oauth';
  static const scopes = 'repo user notifications gist read:org workflow';
  
  static const tokenEndpoint = 'https://github.com/login/oauth/access_token';
  static const authUrl = 'https://github.com/login/oauth/authorize';
}
