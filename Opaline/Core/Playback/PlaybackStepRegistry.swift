import Foundation

/// Every way this app knows how to play a video, in the order they are
/// offered by default.
///
/// Composed here rather than switched on anywhere: the registry is the only
/// place that knows which clients and deliveries exist.
struct PlaybackStepRegistry {
    static let `default` = PlaybackStepRegistry(steps: [
        PlaybackStep(
            id: "visionos.range",
            title: "visionOS · byte ranges",
            requiresSignIn: false
        ) { apiClient in
            innertube(
                apiClient: apiClient,
                client: VisionOSClient(),
                delivery: ByteRangeDeliveryFactory(),
                title: "visionos.range"
            )
        },
        PlaybackStep(
            id: "tv.sabr",
            title: "TV · SABR",
            requiresSignIn: true
        ) { apiClient in
            innertube(
                apiClient: apiClient,
                client: TVClient(),
                delivery: SABRDeliveryFactory(),
                title: "tv.sabr"
            )
        },
        PlaybackStep(
            id: "visionos.sabr",
            title: "visionOS · SABR",
            requiresSignIn: false
        ) { apiClient in
            innertube(
                apiClient: apiClient,
                client: VisionOSClient(),
                delivery: SABRDeliveryFactory(),
                title: "visionos.sabr"
            )
        },
        PlaybackStep(
            id: "progressive",
            title: "Progressive 360p",
            requiresSignIn: false
        ) { apiClient in
            ProgressiveSource(apiClient: apiClient)
        },
        PlaybackStep(
            id: "web.hls",
            title: "Web · native HLS",
            requiresSignIn: false,
            detail: "settings.playbackChain.webHLS".localized,
            timeout: 45
        ) { _ in
            NativeWebHLSSource()
        },
        PlaybackStep(
            id: "web.embedded.range",
            title: "Embedded web · byte ranges",
            requiresSignIn: false,
            detail: "settings.playbackChain.embedded".localized,
            timeout: 45
        ) { apiClient in
            webRange(apiClient: apiClient, profile: .embedded, name: "web.embedded.range")
        },
        PlaybackStep(
            id: "web.mobile.hls",
            title: "Mobile web · native HLS",
            requiresSignIn: false,
            detail: "settings.playbackChain.mobileHLS".localized,
            timeout: 45
        ) { _ in
            NativeWebHLSSource(name: "web.mobile.hls", profile: .mobile)
        },
        PlaybackStep(
            id: "web.embedded.hls",
            title: "Embedded web · native HLS",
            requiresSignIn: false,
            detail: "settings.playbackChain.embeddedHLS".localized,
            timeout: 45
        ) { _ in
            NativeWebHLSSource(name: "web.embedded.hls", profile: .embedded)
        },
        PlaybackStep(
            id: "web.tv.range",
            title: "TV compatibility · byte ranges",
            requiresSignIn: false,
            detail: "settings.playbackChain.tvCompatibility".localized,
            timeout: 45,
            requiresWebsiteSignIn: true
        ) { apiClient in
            webRange(apiClient: apiClient, profile: .legacyTV, name: "web.tv.range")
        }
    ])

    let steps: [PlaybackStep]

    private static func innertube(
        apiClient: WatchService,
        client: PlaybackClient,
        delivery: StreamDeliveryFactory,
        title: String
    ) -> VideoSource {
        InnertubeVideoSource(
            apiClient: apiClient,
            client: client,
            name: title,
            deliveryFactory: delivery
        )
    }

    private static func webRange(
        apiClient: WatchService, profile: WebPlaybackProfile, name: String
    ) -> VideoSource {
        let loader = WebPlaybackLoader(profile: profile, delivery: .byteRanges)
        return InnertubeVideoSource(
            apiClient: apiClient,
            client: WebRangeClient(profile: profile),
            name: name,
            deliveryFactory: WebRangeDeliveryFactory(loader: loader),
            customLoader: loader.load,
            cancelCustomLoader: loader.cancel
        )
    }

    func step(id: String) -> PlaybackStep? {
        steps.first { $0.id == id }
    }
}
