# Physical iPhone acceptance — Vibes 0.2.0

Not executed in the cloud workspace. Record iPhone model, iOS, build, network,
region, audible output and widget/native states. Simulator success or metadata
HTTP 200 cannot substitute for physical-device audio verification.

1. **One tap:** import `https://soundcloud.com/forss/flickermood` (public official
   Widget example). Open Library; tap its row once. Do not touch the iframe.
   Confirm audible audio, advancing official position and native playing state,
   without an extra screen/confirmation. If it fails, record the finite error
   and whether manual widget Play before timeout works. Manual Play is a useful
   fallback/diagnostic but does not meet one-tap acceptance.
2. **Pause/resume:** native Pause must silence audio and receive paused state;
   native Play must resume. Test official widget controls too; native state must
   follow actual events. No second engine or reload on ordinary resume.
3. **Switch:** add a second embeddable public track. Switch A/B 20 times rapidly,
   while playing/loading/paused. Only final selection may play/update/error;
   previous audio stops first. No overlap, stale title, crash or infinite spinner.
4. **Tabs:** switch Search/Library while playing/paused. The dock/widget remains
   present. Opening an actual search browser stops SoundCloud first (the browser
   can contain audio); dismissal must unload that browser's media.
5. **Lock/background:** lock for 30 seconds and two minutes; switch apps. Record
   if audio continues or WebKit suspends it. Do not infer continuity from a native
   label. On return, actual pause must be reflected without auto-resuming.
   Native lock-screen remote controls/background continuity are not promised.
6. **Internet:** airplane mode before selection must fail within 30s. Disconnect
   while playing: buffered audio may continue; after progress stops, foreground
   watchdog must fail within 20s of the last advancing event. Restore network
   and retry; only selected item restarts. Loading/pause controls stay responsive.
7. **Unavailable:** try a previously saved track later deleted/restricted or
   region-blocked. Expect widget error or finite timeout, never a restriction
   bypass. Initial paused/buffering events must not cancel first startup.
8. **Routes/interruption:** unplug wired/Bluetooth headphones, receive a call or
   Siri interruption. Pause safely, reflect acknowledgement and avoid automatic
   restart. Verify ordinary playback can resume afterward.
9. **Stop/retry:** close dock while loading/playing; late callbacks cannot revive
   audio. Retry after a widget/network error, then close again.
10. **Spotify:** open a Spotify item. SC stops; official Spotify embed remains,
    with preview/full-playback disclaimer. Dismissal stops embed audio. Opening
    a link/preview is not represented as full native Spotify playback; no mixing.
11. **Migration/attribution:** old saved items load. SoundCloud creator, source,
    artwork, controls and original links remain visible/usable. Test large text;
    branding and advertising must not be covered to shrink the dock.

One-tap acceptance remains open until case 1 passes on a physical iPhone with
audible output and no second playback action. Distinguish unavailable content,
network/consent failures and autoplay restrictions when recording failure.
