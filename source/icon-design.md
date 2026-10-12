# uTube icon

Generated original artwork packaged into the app icon, alternate icon, launch image and AltStore source assets. Existing size requirements were preserved; iOS app icons are opaque RGB PNGs.

Prompt: Create a finished square iOS app icon for uTube. An original white lowercase u monogram incorporates a crisp right-pointing play triangle. Full-bleed vivid coral-to-red gradient background, clear silhouette at small sizes, premium simple geometry. No lettering beyond the u, no mockup, no device frame, no border and no pre-rounded outer corners.

Primary asset: `source/utube-icon.png` (the same artwork as `source/icon.png`, with a fresh URL for AltStore). iOS catalog: `Opaline/Assets.xcassets/AppIconOpaline.appiconset`. The internal catalog name stays stable for updates; its artwork is replaced.


# kharrison Apps source icon

The shared source represents kharrison’s personal apps, games, and projects. Its name, subtitle, About text, website link, tint, and icon are independent of either app. The source identifier and URL remain stable so existing subscribers receive the update.

Asset: `source/kharrison-apps-icon-v1.png`. Created with the built-in image-generation tool, then resized to an opaque 1024 × 1024 PNG for the source. uTube keeps its own red app icon.

Prompt: Use case: logo-brand. Create one finished square 1024x1024 app-source icon for a personal AltStore collection containing both apps and games. A bold, beautifully crafted abstract stack of three rounded app tiles, subtly fanned and overlapping, with one small four-point light glint at the upper right. Warm pearl front tile, luminous teal middle tile, deep cobalt rear tile; rich midnight-blue to teal full-bleed background. Modern softly dimensional polished enamel/glass, restrained lighting, exceptionally clear silhouette at small icon sizes. Center the compact emblem and fill roughly 70% of the square, balanced generous safe margins. No words, no letters, no numbers, no play button, no YouTube or Apple/AltStore logos, no dragon, no flame, no border, no device mockup, no rounded outer corners, no transparent canvas. Output only the finished icon, not a presentation sheet.

# The Last Dragonrider icon

The app master lives in `kharrisongit/ember/native/Resources/AppIcon.png`. It is rendered deterministically from frame 2 of `assets/ui/title-rider-source.webp`, with the same magenta key and black silhouette as `js/title-screen.js`. `native/render-icon.mjs` adds the existing title’s blue/teal palette, soft halo, and sparse stars. `native/make-icons.swift` generates the iOS sizes. The release’s 1024-pixel icon is also used by its AltStore listing. No AI reinterpretation of Corin or Aurelius is used.
