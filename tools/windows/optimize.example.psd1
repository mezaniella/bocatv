# Template for optimize.ps1. Copy it to local\optimize.psd1 (git ignores local\) and edit the copy:
# optimize.ps1 uses local\optimize.psd1 when it exists, this file otherwise.
#
# Only packages that exist on (almost) every Android TV / Google TV are listed. Your TV's own bloat
# (vendor demos, factory menus, vendor recommendation rows) differs by brand: look for your model in
# examples\<tv>\debloat.txt and add its packages to Base, or find them with diagnose.ps1
# (backup\reports\...\packages-system.txt). Never add Live TV / HDMI, remote, Play Store, Play
# Services, WebView or launcher packages: see docs\RECOVERY.md.
@{
    Packages = @{
        # Always applied with -Apply: pm disable-user, undone by the generated revert script.
        Base = @(
            # --- Telemetry, feedback and ads ---
            'com.android.tv.feedbackconsent'              # consent screen for sending feedback
            'com.google.android.feedback'                 # sends bug reports to Google
            'com.android.federatedcompute.services'       # federated learning
            'com.android.ondevicepersonalization.services' # ad personalisation
            'com.android.adservices.api'                  # Privacy Sandbox / ads
            # --- Rarely used on a TV ---
            'com.google.android.play.games'               # Play Games
            'com.google.android.syncadapters.calendar'    # calendar sync
            'com.android.dynsystem'                       # GSI installer
            'com.android.hotspot2.osulogin'               # Hotspot 2.0 sign-in
            'com.android.wallpaperbackup'                 # wallpaper backup
            'com.google.android.backdrop'                 # "ambient" screensaver; pick the launcher's Clock instead
            # --- Your TV's vendor packages go here (see examples\<tv>\debloat.txt) ---
        )
        # Optional groups: optimize.ps1 -Include Assistant,Recommendations (or -Include All)
        Assistant = @(
            'com.google.android.katniss'                  # Google Assistant / voice search: the remote's mic stops working
            'com.google.android.apps.mediashell'          # Chromecast built-in
        )
        Recommendations = @(
            'com.google.android.tvrecommendations'        # stock launcher's recommendation rows
        )
        Streaming = @(
            'com.google.android.youtube.tvmusic'          # YouTube Music
        )
    }

    # Uninstalled for good (pm uninstall). NOT undone by the revert script: reinstall from the Play Store.
    # Only apps you installed yourself.
    Uninstall = @(
    )

    # Removed for user 0 only (pm uninstall --user 0): for a system app that some service keeps enabling
    # again after a disable. The APK stays on the system; undone with cmd package install-existing.
    RemoveForUser = @(
    )

    # No background work (appops RUN_ANY_IN_BACKGROUND / RUN_IN_BACKGROUND = ignore): the app no longer
    # starts at boot or stays in memory, and works normally when you open it. Big win on 1 GB TVs.
    NoBackground = @(
        'com.netflix.ninja'
        'com.disney.disneyplus'
        'com.wbd.stream'
        'com.amazon.amazonvideo.livingroom'
        'com.google.android.youtube.tv'
    )

    Settings = @(
        @{ Ns = 'global'; Key = 'window_animation_scale';     Value = '0.5'; Why = 'Faster animations' }
        @{ Ns = 'global'; Key = 'transition_animation_scale'; Value = '0.5'; Why = 'Faster animations' }
        @{ Ns = 'global'; Key = 'animator_duration_scale';    Value = '0.5'; Why = 'Faster animations' }
        @{ Ns = 'global'; Key = 'send_action_app_error';      Value = '0';   Why = 'No crash reports' }
        @{ Ns = 'secure'; Key = 'send_action_app_error';      Value = '0';   Why = 'No crash reports' }
        @{ Ns = 'global'; Key = 'wifi_scan_always_enabled';   Value = '0';   Why = 'No background Wi-Fi scans' }
        @{ Ns = 'global'; Key = 'ble_scan_always_enabled';    Value = '0';   Why = 'No background Bluetooth scans' }
        # Optional: ad-blocking Private DNS. The resolver sees every query the TV makes; remove to skip.
        @{ Ns = 'global'; Key = 'private_dns_specifier';      Value = 'dns.adguard-dns.com'; Why = 'Ad-blocking DNS (AdGuard)' }
        @{ Ns = 'global'; Key = 'private_dns_mode';           Value = 'hostname';            Why = 'Private DNS on' }
    )
}
