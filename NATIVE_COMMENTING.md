# Inline commenting in uTube

Write directly in the comments list and tap **Send**. Replies use the same inline box. Typing, sending and connecting an account never deliberately pause the player, and a submitted comment appears only after YouTube returns its created resource.

## Connect once, without app registration

1. Tap **Connect YouTube for commenting** below the comments, or open **Settings → Commenting account**.
2. Sign in on the visible YouTube website, choose the channel you want, and tap **Use account**. Check the channel shown by uTube before posting.
3. Close the account screen and type in the comments list. Connecting never submits a draft.

There is no Google Cloud project, client ID or uTube app registration to create. The existing TV-style viewing login cannot supply the website session needed to post, so commenting still needs this one-time website sign-in. If Google rejects the embedded sign-in browser, this route is unavailable; uTube does not bypass that rejection. Session expiration can require reconnecting.

This is an unofficial YouTube website connection and can break when YouTube changes. It does not make account activity anonymous or guarantee that Google will not identify a third-party client. Public comments identify the selected YouTube channel.

## Privacy and behavior

The sign-in browser uses temporary website storage and does not intercept passwords. After the user taps Use account, uTube keeps only secure YouTube-domain session cookies and the selected website account context in the device Keychain, accessible only while unlocked and never synchronized to other devices. Requests go directly to `https://www.youtube.com` using a dedicated ephemeral transport with no request logging, shared cookie jar, redirects, or automatic comment retries. No intermediary server receives the session or comment.

The app fetches the signed-in comments page and uses only its offered create-comment or reply action. It does not forge a posting capability when comments are unavailable or execute account-creation or challenge actions returned by the website. Unsupported responses keep the draft and show an error.

Drafts stay in memory until posted or the app exits, separately for each video and reply. An in-flight request cannot clear another video's draft. After an ambiguous response, check the list before sending again to avoid a duplicate.

Disconnect deletes the local website session and any legacy official-API commenting credentials. Existing official-API accounts connected in an older build remain usable until disconnected, but the developer setup form is no longer presented.

## AirPlay changes and validation

The audio session uses Apple's long-form video route policy on iOS 13+. After a temporary audio interruption, the app reactivates the session and resumes only when iOS permits it, the same player is still present, and the user has not paused or disconnected the output. Other apps' ongoing audio interruptions are respected. Diagnostic entries include playback state, route type, background state and buffer state, without adding credentials or comment content to logs.

Automated checks cover draft isolation and duplicate-send prevention, cookie domain/expiry handling, selected account context, server response handling, and interruption recovery policy. CI compiles the iOS app with strict SwiftLint. Automated checks do not log in to Google, send a live comment or establish a physical AirPlay connection.

Device checks still required: connect a commenting session; deliberately send a comment and reply; play on the receiver for at least ten minutes while using another app; verify manual pause stays paused, disconnection does not switch unexpectedly to the phone speaker, and an ended interruption resumes only when allowed. These changes address identified gaps but do not establish the cause of the reported delayed TV stop without receiver testing or device logs.

## References

- [YouTube.js website authentication](https://ytjs.dev/guide/authentication)
- [YouTube.js comment creation](https://github.com/LuanRT/YouTube.js/blob/main/src/parser/youtube/Comments.ts)
- [Apple AirPlay integration](https://developer.apple.com/documentation/avfoundation/integrating-airplay-for-long-form-video-apps)
- [Apple audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
