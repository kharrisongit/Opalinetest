# Native commenting in uTube

uTube has a native comment editor for videos and Shorts, including replies. Posting uses the official YouTube Data API. It needs a separate Google authorization from the app's playback account. A Google OAuth client is not bundled with this fork.

## One-time setup

1. In [Google Cloud Console](https://console.cloud.google.com/), create or select your own project and enable **YouTube Data API v3** in the API Library.
2. Configure **Google Auth Platform → Branding** with an app name such as **uTube** and your support/contact email. For personal testing, set the audience to **External**, keep it in **Testing**, and add the Google account you will use under **Test users**.
3. Under **Data Access**, add `https://www.googleapis.com/auth/youtube.force-ssl`. This is the scope Google requires for creating comments; Google's consent screen describes broader YouTube management permissions. uTube uses it to identify your channel and post only the comments you explicitly submit.
4. Under **Clients**, create an **iOS** OAuth client. Use the installed app's bundle identifier. The distributed IPA uses `com.verback.YTLite`; sideloading software may change it when signing. The commenting account screen displays the installed identifier to copy. App Store ID is optional because this app is sideloaded. This build does not integrate App Check.
5. Copy the **Client ID** ending in `.apps.googleusercontent.com`. In uTube, open **Settings → Commenting account**, paste it, and tap **Connect Google account**. Do not paste an API key or client secret.
6. Complete Google's sign-in and consent. Back in uTube, confirm the displayed YouTube channel is the one you intend to post as.

Open a video's comments and tap **Write a comment**, or tap **Reply** beneath a comment. Enter your text and tap **Post**. Connecting an account never posts a draft automatically.

Google may show an unverified-app notice for your own test project. Public distribution of a shared OAuth client can require Google's verification. Test-mode refresh tokens can expire after seven days, so you may need to reconnect. A YouTube channel must exist on the selected account, and the video's creator must allow comments.

## Account and drafts

Access and refresh tokens stay in the iOS Keychain on this device. They are sent only to Google's OAuth and YouTube API endpoints; request logging and the app's playback authentication middleware are not used. The Client ID is a public identifier, saved locally. Disconnect removes local credentials; revoke the grant separately in your Google account if desired.

Drafts stay in memory until posted or the app exits. A failed request leaves the draft visible. If the app cannot tell whether YouTube accepted a comment, check the comment list before posting again: writes are never retried automatically.

## Validation

The build runs deterministic checks against the production OAuth, response parsing, comment body, and AirPlay policy code. It also runs the existing source publisher checks and builds the iOS app with strict SwiftLint. These checks do not authorize a Google account or publish a comment. Complete the account setup and check a deliberate post yourself to validate your Google project.

For the AirPlay fix, start a video on your receiver, leave uTube, lock the phone, and return. Check both the Background Playback toggle states. Playback should continue on AirPlay; manually pausing should stay paused. Test disconnecting the route and using PiP independently too. A physical receiver cannot be verified by the build job.

## References

- [Google OAuth for iOS and desktop apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Create a top-level comment](https://developers.google.com/youtube/v3/docs/commentThreads/insert)
- [Create a reply](https://developers.google.com/youtube/v3/docs/comments/insert)
- [Apple web authentication sessions](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
