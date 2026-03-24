import SwiftUI

public struct RootView: View {
    @StateObject private var viewModel: AppViewModel

    public init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: AppViewModel(environment: environment))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                PrivadiTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        currentStageView
                            .frame(maxWidth: 660)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(
                            0,
                            proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 24
                        ),
                        alignment: .center
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, max(16, proxy.safeAreaInsets.top + 6))
                    .padding(.bottom, max(20, proxy.safeAreaInsets.bottom + 12))
                }
                .id(stageIdentifier)
            }
        }
        .preferredColorScheme(.light)
        .animation(.spring(response: 0.58, dampingFraction: 0.88), value: stageIdentifier)
        .task {
            await viewModel.bootstrap()
        }
    }

    @ViewBuilder
    private var currentStageView: some View {
        switch viewModel.stage {
        case .privacy:
            PrivacyPromiseView(action: viewModel.continueFromPrivacy)
        case .permissions:
            PermissionsPrimerView(
                action: viewModel.continueFromPermissions,
                previewAction: viewModel.startLimitedPreview
            )
        case .paywall:
            HardPaywallView(
                annualProduct: viewModel.product(for: .annual),
                monthlyProduct: viewModel.product(for: .monthly),
                purchaseInProgress: viewModel.purchaseInProgress,
                restoreInProgress: viewModel.restoreInProgress,
                statusText: viewModel.paywallStatusText,
                manageSubscriptionsURL: viewModel.subscriptionState.manageSubscriptionsURL,
                annualAction: viewModel.startAnnualTrial,
                monthlyAction: viewModel.startMonthlyPlan,
                restoreAction: viewModel.restorePurchases,
                previewAction: viewModel.startLimitedPreview
            )
        case .scanning:
            ScanProgressView(statusText: viewModel.statusText)
        case .dashboard:
            DashboardView(viewModel: viewModel)
        }
    }

    private var stageIdentifier: String {
        switch viewModel.stage {
        case .privacy:
            "privacy"
        case .permissions:
            "permissions"
        case .paywall:
            "paywall"
        case .scanning:
            "scanning"
        case .dashboard:
            "dashboard"
        }
    }
}

public struct PrivacyPromiseView: View {
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        ViewThatFits(in: .vertical) {
            privacyLayout(
                brandSize: 40,
                orbSize: 270,
                titleSize: 34,
                bodySize: 18,
                spacing: 22,
                featureStyle: .full
            )

            privacyLayout(
                brandSize: 34,
                orbSize: 220,
                titleSize: 30,
                bodySize: 16,
                spacing: 16,
                featureStyle: .compact
            )
        }
    }

    @ViewBuilder
    private func privacyLayout(
        brandSize: CGFloat,
        orbSize: CGFloat,
        titleSize: CGFloat,
        bodySize: CGFloat,
        spacing: CGFloat,
        featureStyle: PrivacyFeatureStyle
    ) -> some View {
        VStack(spacing: spacing) {
            BrandMark(subtitle: "private storage recovery", size: brandSize)

            StorageOrbView(
                primaryText: "100%",
                secondaryText: "Offline",
                caption: "No cloud upload. No hidden telemetry.",
                size: orbSize
            )

            VStack(spacing: 10) {
                Text("Your space, secured.")
                    .font(PrivadiTheme.titleFont(size: titleSize))
                    .foregroundStyle(PrivadiTheme.ink)
                    .multilineTextAlignment(.center)

                Text("Privadi scans photos, videos, contacts, and your secure vault on-device so you can see reclaimable space in minutes.")
                    .font(.system(size: bodySize, weight: .medium, design: .rounded))
                    .foregroundStyle(PrivadiTheme.mutedInk)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, featureStyle == .compact ? 8 : 0)

            ViewThatFits {
                HStack(spacing: 10) {
                    StatusBadge(text: "100% Offline", icon: "lock.fill")
                    StatusBadge(text: "Review First", icon: "eye.fill")
                    StatusBadge(text: "Encrypted Vault", icon: "shield.fill")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 10) {
                    StatusBadge(text: "100% Offline", icon: "lock.fill")
                    StatusBadge(text: "Review First", icon: "eye.fill")
                    StatusBadge(text: "Encrypted Vault", icon: "shield.fill")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if featureStyle == .full {
                VStack(spacing: 12) {
                    FeatureStrip(icon: "sparkles.square.filled.on.square", title: "Spot duplicates, similar shots, and low-quality captures.")
                    FeatureStrip(icon: "video.fill", title: "Reveal large videos and local compression opportunities.")
                    FeatureStrip(icon: "person.crop.circle.badge.checkmark", title: "Clean up contacts and keep sensitive files locked offline.")
                }
            } else {
                VStack(spacing: 10) {
                    FeaturePoint(icon: "sparkles.square.filled.on.square", title: "Spot duplicates, similar shots, and low-quality captures.")
                    FeaturePoint(icon: "video.fill", title: "Reveal large videos and local compression opportunities.")
                    FeaturePoint(icon: "person.crop.circle.badge.checkmark", title: "Clean up contacts and keep sensitive files locked offline.")
                }
                .privadiGlassCard(cornerRadius: 30, padding: 16)
            }

            Button("Purify Space") {
                action()
            }
            .buttonStyle(PrivadiPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }
}

public struct PermissionsPrimerView: View {
    let action: () -> Void
    let previewAction: () -> Void

    public init(action: @escaping () -> Void, previewAction: @escaping () -> Void) {
        self.action = action
        self.previewAction = previewAction
    }

    public var body: some View {
        ViewThatFits(in: .vertical) {
            permissionsLayout(titleSize: 36, bodySize: 18, spacing: 22, cardPadding: 22)
            permissionsLayout(titleSize: 32, bodySize: 16, spacing: 16, cardPadding: 18)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func permissionsLayout(
        titleSize: CGFloat,
        bodySize: CGFloat,
        spacing: CGFloat,
        cardPadding: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            StageHeader(
                eyebrow: "Private Access",
                title: "Give Privadi the access it needs to uncover cleanup wins.",
                bodyText: "The analysis stays on your iPhone. Permissions only unlock the categories you want Privadi to review.",
                titleSize: titleSize,
                bodySize: bodySize
            )

            VStack(spacing: 14) {
                PermissionNeedCard(
                    icon: "photo.stack.fill",
                    title: "Photos Library",
                    bodyText: "Required for duplicates, similar shots, screenshots, Live Photos, and large-video analysis.",
                    padding: cardPadding
                )

                PermissionNeedCard(
                    icon: "person.2.fill",
                    title: "Contacts",
                    bodyText: "Used for duplicate and incomplete contact suggestions. Matching stays local to your device.",
                    padding: cardPadding
                )
            }

            ViewThatFits {
                HStack(spacing: 12) {
                    StatusBadge(text: "On-device analysis", icon: "iphone")
                    StatusBadge(text: "No background upload", icon: "icloud.slash.fill")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 10) {
                    StatusBadge(text: "On-device analysis", icon: "iphone")
                    StatusBadge(text: "No background upload", icon: "icloud.slash.fill")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Button("Allow and Continue") {
                action()
            }
            .buttonStyle(PrivadiPrimaryButtonStyle())

            Button("Preview My Library First") {
                previewAction()
            }
            .buttonStyle(PrivadiSecondaryButtonStyle())

            Text("Privadi is honest about iOS limits: it reveals what is reclaimable, then lets you review each action before anything is removed.")
                .font(.system(size: max(15, bodySize - 1), weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.mutedInk)

            Text("Limited Preview scans up to \(ScanScope.preview.assetLimit ?? 30) recent photos or videos on-device. Contacts stay off until the full private scan.")
                .font(.system(size: max(14, bodySize - 2), weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.faintInk)
        }
    }
}

public struct HardPaywallView: View {
    let annualProduct: SubscriptionProduct?
    let monthlyProduct: SubscriptionProduct?
    let purchaseInProgress: SubscriptionPlan?
    let restoreInProgress: Bool
    let statusText: String?
    let manageSubscriptionsURL: URL?
    let annualAction: () -> Void
    let monthlyAction: () -> Void
    let restoreAction: () -> Void
    let previewAction: () -> Void

    public init(
        annualProduct: SubscriptionProduct?,
        monthlyProduct: SubscriptionProduct?,
        purchaseInProgress: SubscriptionPlan?,
        restoreInProgress: Bool,
        statusText: String?,
        manageSubscriptionsURL: URL?,
        annualAction: @escaping () -> Void,
        monthlyAction: @escaping () -> Void,
        restoreAction: @escaping () -> Void,
        previewAction: @escaping () -> Void
    ) {
        self.annualProduct = annualProduct
        self.monthlyProduct = monthlyProduct
        self.purchaseInProgress = purchaseInProgress
        self.restoreInProgress = restoreInProgress
        self.statusText = statusText
        self.manageSubscriptionsURL = manageSubscriptionsURL
        self.annualAction = annualAction
        self.monthlyAction = monthlyAction
        self.restoreAction = restoreAction
        self.previewAction = previewAction
    }

    public var body: some View {
        ViewThatFits(in: .vertical) {
            paywallLayout(titleSize: 36, bodySize: 18, spacing: 20, compactCards: false)
            paywallLayout(titleSize: 32, bodySize: 16, spacing: 14, compactCards: true)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func paywallLayout(
        titleSize: CGFloat,
        bodySize: CGFloat,
        spacing: CGFloat,
        compactCards: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            StageHeader(
                eyebrow: "Start Cleaning Privately",
                title: "Reveal your biggest storage wins and keep every scan offline.",
                bodyText: "See reclaimable gigabytes, estimate compression savings, and use the encrypted vault without routing personal media through the cloud.",
                titleSize: titleSize,
                bodySize: bodySize
            )

            PlanCard(
                badge: "Best value",
                title: annualProduct?.displayName ?? "Annual",
                price: annualProduct?.displayPrice ?? "Loading price",
                detail: annualProduct?.detailText ?? "Loading the current App Store pricing",
                footer: "Priority for people who want the premium flow from day one.",
                buttonTitle: purchaseInProgress == .annual ? "Processing..." : "Choose Annual",
                primary: true,
                compact: compactCards,
                isDisabled: annualProduct == nil || purchaseInProgress != nil || restoreInProgress,
                action: annualAction
            )

            PlanCard(
                badge: nil,
                title: monthlyProduct?.displayName ?? "Monthly",
                price: monthlyProduct?.displayPrice ?? "Loading price",
                detail: monthlyProduct?.detailText ?? "Loading the current App Store pricing",
                footer: "Good if you want shorter commitment while you test the workflow.",
                buttonTitle: purchaseInProgress == .monthly ? "Processing..." : "Choose Monthly",
                primary: false,
                compact: compactCards,
                isDisabled: monthlyProduct == nil || purchaseInProgress != nil || restoreInProgress,
                action: monthlyAction
            )

            if let statusText {
                Text(statusText)
                    .font(.system(size: max(14, bodySize - 1), weight: .medium, design: .rounded))
                    .foregroundStyle(PrivadiTheme.warning)
            }

            ViewThatFits {
                HStack(spacing: 10) {
                    StatusBadge(text: "Offline scan", icon: "lock.fill")
                    StatusBadge(text: "Encrypted vault", icon: "shield.lefthalf.filled")
                    StatusBadge(text: "Compression center", icon: "sparkles")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 10) {
                    StatusBadge(text: "Offline scan", icon: "lock.fill")
                    StatusBadge(text: "Encrypted vault", icon: "shield.lefthalf.filled")
                    StatusBadge(text: "Compression center", icon: "sparkles")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Button("Preview My Library First") {
                previewAction()
            }
            .buttonStyle(PrivadiSecondaryButtonStyle())
            .disabled(purchaseInProgress != nil || restoreInProgress)

            HStack(spacing: 14) {
                Button(restoreInProgress ? "Restoring..." : "Restore Purchases") {
                    restoreAction()
                }
                .buttonStyle(.plain)
                .foregroundStyle(PrivadiTheme.accent)
                .disabled(restoreInProgress || purchaseInProgress != nil)

                if let manageSubscriptionsURL {
                    Link("Manage Subscription", destination: manageSubscriptionsURL)
                        .foregroundStyle(PrivadiTheme.faintInk)
                }
            }

            Text("Limited Preview scans up to \(ScanScope.preview.assetLimit ?? 30) recent photos or videos from your device. Start a plan when you want the full-library version.")
                .font(.system(size: max(14, bodySize - 2), weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.faintInk)
        }
    }
}

public struct ScanProgressView: View {
    let statusText: String

    public init(statusText: String) {
        self.statusText = statusText
    }

    public var body: some View {
        VStack(spacing: 26) {
            BrandMark(subtitle: "building your cleanup plan")
                .padding(.top, 10)

            ScanOrbView(statusText: statusText)
                .padding(.top, 6)

            VStack(spacing: 16) {
                FeatureStrip(icon: "photo.on.rectangle.angled", title: "Analyzing duplicates, similar shots, and low-quality captures.")
                FeatureStrip(icon: "video.badge.waveform", title: "Estimating savings from large videos and heavy media.")
                FeatureStrip(icon: "lock.shield.fill", title: "Preparing a review-first cleanup plan that stays on your device.")
            }
        }
    }
}

public struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var email = "compromised@example.com"
    @State private var showVaultSetup = false
    @State private var showVaultUnlock = false
    @State private var vaultPasscode = ""
    @State private var vaultPasscodeConfirmation = ""
    @State private var vaultUnlockPasscode = ""
    @State private var enableBiometrics = true

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if let summary = viewModel.summary, viewModel.selection != nil {
            let categories = viewModel.cleanupCategories
            let reclaimableBytes = viewModel.selectedReclaimableBytes()
            let isLimitedPreview = viewModel.experienceMode == .limitedPreview

            VStack(alignment: .leading, spacing: 22) {
                Text("Privadi")
                    .font(PrivadiTheme.titleFont(size: 28))
                    .foregroundStyle(PrivadiTheme.ink)

                if isLimitedPreview {
                    PreviewModeBanner(action: viewModel.showPaywallFromPreview)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(isLimitedPreview ? "Preview Reclaimable Space" : "Reclaimable Space")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(PrivadiTheme.faintInk)

                    Text(reclaimableBytes.privadiByteString)
                        .font(PrivadiTheme.valueFont(size: 64))
                        .foregroundStyle(PrivadiTheme.ink)
                        .contentTransition(.numericText())

                    Text(viewModel.statusText)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(PrivadiTheme.mutedInk)
                }

                ViewThatFits {
                    HStack(spacing: 12) {
                        StatusBadge(text: isLimitedPreview ? "Limited device preview" : "100% Offline", icon: "lock.fill")
                        StatusBadge(text: isLimitedPreview ? "\(summary.totalItems) preview items" : "\(summary.totalItems) items scanned", icon: "sparkles")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 12) {
                        StatusBadge(text: isLimitedPreview ? "Limited device preview" : "100% Offline", icon: "lock.fill")
                        StatusBadge(text: isLimitedPreview ? "\(summary.totalItems) preview items" : "\(summary.totalItems) items scanned", icon: "sparkles")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                VStack(spacing: 16) {
                    ForEach(categories) { category in
                        CleanupCategoryCard(
                            category: category,
                            isSelected: viewModel.selectedCleanupCategoryIDs.contains(category.id)
                        ) {
                            viewModel.toggleCleanupCategory(category.id)
                        }
                    }
                }

                Button {
                    viewModel.reviewCleanupPlan()
                } label: {
                    HStack(spacing: 10) {
                        Text(
                            reclaimableBytes > 0
                                ? (isLimitedPreview ? "Preview \(reclaimableBytes.privadiByteString)" : "Review Delete Plan")
                                : (isLimitedPreview ? "Preview Cleanup Plan" : "Review Cleanup Plan")
                        )
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrivadiPrimaryButtonStyle())

                Text("Private Tools")
                    .font(PrivadiTheme.titleFont(size: 24))
                    .foregroundStyle(PrivadiTheme.ink)
                    .padding(.top, 4)

                UtilityCard(
                    title: "Secure Vault",
                    bodyText: isLimitedPreview
                        ? "\(viewModel.vaultRecords.count) preview items are protected locally. Vault setup is available once you unlock the full scan."
                        : vaultBodyText,
                    metric: "Vault items: \(viewModel.vaultRecords.count)",
                    icon: "lock.square.stack.fill",
                    buttonTitle: vaultButtonTitle(isLimitedPreview: isLimitedPreview),
                    action: {
                        if isLimitedPreview {
                            viewModel.showPaywallFromPreview()
                        } else if viewModel.vaultAccessState == .unconfigured {
                            showVaultSetup = true
                        } else if viewModel.vaultAccessState == .locked {
                            showVaultUnlock = true
                        } else {
                            viewModel.saveSampleToConfiguredVault()
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        DashboardIconBubble(icon: "envelope.badge.shield.half.filled")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email Security Check")
                                .font(PrivadiTheme.titleFont(size: 22))
                                .foregroundStyle(PrivadiTheme.ink)

                            Text(
                                isLimitedPreview
                                    ? "Try the offline breach check with a sample or your own address. The email never leaves your device."
                                    : "Check an address against the local breach index. The email never leaves your device."
                            )
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(PrivadiTheme.mutedInk)
                        }
                    }

                    TextField("Email", text: $email)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(PrivadiTheme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.62))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.78), lineWidth: 1)
                        }

                    Button("Check Offline") {
                        viewModel.runBreachCheck(email: email)
                    }
                    .buttonStyle(PrivadiSecondaryButtonStyle())

                    if let breachResult = viewModel.breachResult {
                        Text(
                            breachResult.isBreached
                                ? "This address appears in the local breach index."
                                : "No match found in the local breach index."
                        )
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(breachResult.isBreached ? PrivadiTheme.warning : PrivadiTheme.accent)
                    }
                }
                .privadiGlassCard()

                if isLimitedPreview {
                    Button("Unlock My Full Private Scan") {
                        viewModel.showPaywallFromPreview()
                    }
                    .buttonStyle(PrivadiPrimaryButtonStyle())
                }
            }
            .sheet(isPresented: cleanupReviewPresented) {
                if let reviewPlan = viewModel.cleanupReviewPlan {
                    CleanupReviewSheet(
                        plan: reviewPlan,
                        phase: viewModel.cleanupExecutionPhase,
                        confirmAction: viewModel.executeCleanupPlan,
                        cancelAction: viewModel.dismissCleanupReview
                    )
                }
            }
            .sheet(isPresented: $showVaultSetup) {
                VaultSetupSheet(
                    isBiometricsAvailable: viewModel.vaultConfiguration.canUseBiometrics,
                    passcode: $vaultPasscode,
                    confirmation: $vaultPasscodeConfirmation,
                    enableBiometrics: $enableBiometrics,
                    saveAction: {
                        guard vaultPasscode == vaultPasscodeConfirmation else {
                            viewModel.statusText = "The vault passcodes do not match."
                            return
                        }
                        viewModel.configureVault(passcode: vaultPasscode, enableBiometrics: enableBiometrics)
                        vaultPasscode = ""
                        vaultPasscodeConfirmation = ""
                        showVaultSetup = false
                    }
                )
            }
            .sheet(isPresented: $showVaultUnlock) {
                VaultUnlockSheet(
                    biometricsEnabled: viewModel.vaultConfiguration.biometricsEnabled,
                    passcode: $vaultUnlockPasscode,
                    unlockWithPasscodeAction: {
                        let passcode = vaultUnlockPasscode
                        Task {
                            await viewModel.unlockVault(passcode: passcode)
                            if viewModel.vaultAccessState == .unlocked {
                                viewModel.saveSampleToConfiguredVault()
                                vaultUnlockPasscode = ""
                                showVaultUnlock = false
                            }
                        }
                    },
                    unlockWithBiometricsAction: {
                        Task {
                            await viewModel.unlockVaultWithBiometrics()
                            if viewModel.vaultAccessState == .unlocked {
                                viewModel.saveSampleToConfiguredVault()
                                showVaultUnlock = false
                            }
                        }
                    }
                )
            }
        }
    }

    private var cleanupReviewPresented: Binding<Bool> {
        Binding(
            get: { viewModel.cleanupReviewPlan != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissCleanupReview()
                }
            }
        )
    }

    private var vaultBodyText: String {
        if viewModel.vaultAccessState == .unlocked {
            if viewModel.vaultConfiguration.biometricsEnabled {
                return "\(viewModel.vaultRecords.count) items are protected locally. New saves use your configured passcode, with biometrics available for unlock."
            }
            return "\(viewModel.vaultRecords.count) items are protected locally with your passcode-backed encrypted vault."
        }
        if viewModel.vaultAccessState == .locked {
            return "\(viewModel.vaultRecords.count) items are protected locally. Unlock the vault before saving anything new."
        }
        return "Create a private vault passcode and optionally enable Face ID or Touch ID before saving the first protected item."
    }

    private func vaultButtonTitle(isLimitedPreview: Bool) -> String {
        if isLimitedPreview {
            return "Unlock Vault Setup"
        }
        switch viewModel.vaultAccessState {
        case .unconfigured:
            return "Set Up Secure Vault"
        case .locked:
            return "Unlock Vault"
        case .unlocked:
            return "Save Sample Offline"
        }
    }
}

private struct BrandMark: View {
    let subtitle: String
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: 8) {
            Text("Privadi")
                .font(PrivadiTheme.titleFont(size: size))
                .foregroundStyle(PrivadiTheme.ink)

            Text(subtitle)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.faintInk)
                .textCase(.lowercase)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StageHeader: View {
    let eyebrow: String
    let title: String
    let bodyText: String
    var titleSize: CGFloat = 40
    var bodySize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(PrivadiTheme.faintInk)

            Text(title)
                .font(PrivadiTheme.titleFont(size: titleSize))
                .foregroundStyle(PrivadiTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyText)
                .font(.system(size: bodySize, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StorageOrbView: View {
    let primaryText: String
    let secondaryText: String
    let caption: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PrivadiTheme.accent.opacity(0.20),
                            PrivadiTheme.accentLavender.opacity(0.26),
                            PrivadiTheme.accentBlush.opacity(0.22),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 24)

            Circle()
                .fill(Color.white.opacity(0.70))
                .frame(width: size * 0.92, height: size * 0.92)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size * 0.92, height: size * 0.92)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.88), Color.white.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(width: size * 0.92, height: size * 0.92)

            VStack(spacing: 10) {
                Text(primaryText)
                    .font(PrivadiTheme.valueFont(size: size > 300 ? 62 : 50))
                    .foregroundStyle(PrivadiTheme.ink)
                    .minimumScaleFactor(0.7)

                Text(secondaryText)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(PrivadiTheme.mutedInk)

                Text(caption)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(PrivadiTheme.faintInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: PrivadiTheme.accent.opacity(0.12), radius: 50, x: 0, y: 28)
    }
}

private struct ScanOrbView: View {
    let statusText: String

    var body: some View {
        ZStack {
            StorageOrbView(
                primaryText: "Scanning",
                secondaryText: "securely",
                caption: statusText,
                size: 320
            )

            VStack(spacing: 16) {
                ProgressView()
                    .tint(PrivadiTheme.accent)
                    .scaleEffect(1.5)
                    .padding(.bottom, 124)
            }
        }
    }
}

private struct StatusBadge: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(PrivadiTheme.ink)
            .privadiPill()
    }
}

private struct PreviewModeBanner: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Limited Preview")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PrivadiTheme.accent)
                .privadiPill()

            Text("You’re exploring Privadi with your own recent media.")
                .font(PrivadiTheme.titleFont(size: 24))
                .foregroundStyle(PrivadiTheme.ink)

            Text("Privadi scanned up to \(ScanScope.preview.assetLimit ?? 30) recent photos or videos on-device so you can feel the workflow before starting a full private scan. Contacts stay untouched in preview mode.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Button("Unlock My Full Private Scan") {
                action()
            }
            .buttonStyle(PrivadiSecondaryButtonStyle())
        }
        .privadiGlassCard(cornerRadius: 34, padding: 22)
    }
}

private struct FeatureStrip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PrivadiTheme.accent)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.68))
                }

            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .privadiGlassCard(cornerRadius: 28, padding: 18)
    }
}

private enum PrivacyFeatureStyle {
    case full
    case compact
}

private struct FeaturePoint: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PrivadiTheme.accent)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.64))
                }

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct PermissionNeedCard: View {
    let icon: String
    let title: String
    let bodyText: String
    var padding: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            DashboardIconBubble(icon: icon)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(PrivadiTheme.titleFont(size: 24))
                    .foregroundStyle(PrivadiTheme.ink)

                Text(bodyText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PrivadiTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .privadiGlassCard(padding: padding)
    }
}

private struct PlanCard: View {
    let badge: String?
    let title: String
    let price: String
    let detail: String
    let footer: String
    let buttonTitle: String
    let primary: Bool
    var compact: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PrivadiTheme.accent)
                            .privadiPill()
                    }

                    Text(title)
                        .font(PrivadiTheme.titleFont(size: compact ? 28 : 34))
                        .foregroundStyle(PrivadiTheme.ink)
                }

                Spacer(minLength: 12)

                Text(price)
                    .font(.system(size: compact ? 18 : 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(PrivadiTheme.ink)
                    .multilineTextAlignment(.trailing)
            }

            Text(detail)
                .font(.system(size: compact ? 15 : 17, weight: .medium, design: .rounded))
                .foregroundStyle(primary ? PrivadiTheme.accent : PrivadiTheme.mutedInk)

            Text(footer)
                .font(.system(size: compact ? 14 : 15, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.mutedInk)

            if primary {
                Button(buttonTitle) {
                    action()
                }
                .buttonStyle(PrivadiPrimaryButtonStyle())
                .disabled(isDisabled)
            } else {
                Button(buttonTitle) {
                    action()
                }
                .buttonStyle(PrivadiSecondaryButtonStyle())
                .disabled(isDisabled)
            }
        }
        .privadiGlassCard(cornerRadius: 34, padding: compact ? 20 : 24)
    }
}

private struct CleanupCategoryCard: View {
    let category: CleanupReviewCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                DashboardIconBubble(icon: category.icon)

                VStack(alignment: .leading, spacing: 6) {
                    Text(category.title)
                        .font(PrivadiTheme.titleFont(size: 24))
                        .foregroundStyle(PrivadiTheme.ink)

                    Text(category.metric)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(PrivadiTheme.faintInk)

                    Text(category.subtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(PrivadiTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    action()
                } label: {
                    SelectionIndicator(isSelected: isSelected, isDisabled: !category.isSelectable)
                }
                .buttonStyle(.plain)
                .disabled(!category.isSelectable)
            }

            VStack(spacing: 12) {
                ForEach(category.detailLines, id: \.self) { line in
                    HStack {
                        Text(line)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(PrivadiTheme.ink.opacity(0.88))

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .privadiGlassCard(cornerRadius: 34, padding: 24)
    }
}

private struct SelectionIndicator: View {
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? PrivadiTheme.accent : Color.white.opacity(isDisabled ? 0.34 : 0.62))
            .frame(width: 28, height: 28)
            .overlay {
                Circle()
                    .fill(isSelected ? Color.white : PrivadiTheme.faintInk.opacity(isDisabled ? 0.22 : 0.45))
                    .frame(width: 13, height: 13)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.80), lineWidth: 1)
            }
    }
}

private struct DashboardIconBubble: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(PrivadiTheme.accent)
            .frame(width: 58, height: 58)
            .background {
                Circle()
                    .fill(Color.white.opacity(0.66))
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.84), lineWidth: 1)
            }
    }
}

private struct CleanupReviewSheet: View {
    let plan: CleanupReviewPlan
    let phase: AppViewModel.CleanupExecutionPhase
    let confirmAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Review Delete Plan")
                        .font(PrivadiTheme.titleFont(size: 28))
                        .foregroundStyle(PrivadiTheme.ink)

                    Text("Privadi will only delete the exact items listed below after your confirmation.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(PrivadiTheme.mutedInk)

                    Text(plan.estimatedReclaimableBytes.privadiByteString)
                        .font(PrivadiTheme.valueFont(size: 44))
                        .foregroundStyle(PrivadiTheme.ink)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(plan.categories) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.title)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PrivadiTheme.ink)

                                Text(category.subtitle)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(PrivadiTheme.mutedInk)
                            }
                            .privadiGlassCard(cornerRadius: 24, padding: 18)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delete Candidates")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(PrivadiTheme.ink)

                        ForEach(plan.deleteCandidates.prefix(12), id: \.id) { asset in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(asset.name)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PrivadiTheme.ink)

                                    Text(asset.byteSize.privadiByteString)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(PrivadiTheme.faintInk)
                                }

                                Spacer(minLength: 12)

                                Image(systemName: "trash.fill")
                                    .foregroundStyle(PrivadiTheme.warning)
                            }
                            .privadiGlassCard(cornerRadius: 22, padding: 16)
                        }

                        if plan.deleteCandidates.count > 12 {
                            Text("+ \(plan.deleteCandidates.count - 12) more selected items")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(PrivadiTheme.faintInk)
                        }
                    }
                }
                .padding(24)
            }
            .background(PrivadiTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        cancelAction()
                    }
                    .disabled(isExecuting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isExecuting ? "Deleting..." : "Delete Selected") {
                        confirmAction()
                    }
                    .foregroundStyle(PrivadiTheme.warning)
                    .disabled(isExecuting)
                }
            }
        }
    }

    private var isExecuting: Bool {
        if case .executing = phase {
            return true
        }
        return false
    }
}

private struct VaultSetupSheet: View {
    let isBiometricsAvailable: Bool
    @Binding var passcode: String
    @Binding var confirmation: String
    @Binding var enableBiometrics: Bool
    let saveAction: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Vault Security") {
                    SecureField("Passcode", text: $passcode)
                    SecureField("Confirm Passcode", text: $confirmation)
                }

                if isBiometricsAvailable {
                    Section("Unlock") {
                        Toggle("Enable biometric unlock", isOn: $enableBiometrics)
                    }
                }

                Section {
                    Text("Privadi keeps the encrypted vault on your device and stores the vault key material in Keychain.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(PrivadiTheme.mutedInk)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PrivadiTheme.background.ignoresSafeArea())
            .navigationTitle("Set Up Vault")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAction()
                    }
                }
            }
        }
    }
}

private struct VaultUnlockSheet: View {
    let biometricsEnabled: Bool
    @Binding var passcode: String
    let unlockWithPasscodeAction: () -> Void
    let unlockWithBiometricsAction: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Unlock Vault") {
                    SecureField("Passcode", text: $passcode)
                    Button("Unlock with Passcode") {
                        unlockWithPasscodeAction()
                    }
                }

                if biometricsEnabled {
                    Section("Biometrics") {
                        Button("Unlock with Biometrics") {
                            unlockWithBiometricsAction()
                        }
                    }
                }

                Section {
                    Text("Privadi unlocks the vault locally and only keeps the decrypted key material in memory for the current session.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(PrivadiTheme.mutedInk)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PrivadiTheme.background.ignoresSafeArea())
            .navigationTitle("Unlock Vault")
        }
    }
}

private struct UtilityCard: View {
    let title: String
    let bodyText: String
    let metric: String
    let icon: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                DashboardIconBubble(icon: icon)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(PrivadiTheme.titleFont(size: 22))
                        .foregroundStyle(PrivadiTheme.ink)

                    Text(metric)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(PrivadiTheme.faintInk)
                }
            }

            Text(bodyText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PrivadiTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(buttonTitle) {
                action()
            }
            .buttonStyle(PrivadiSecondaryButtonStyle())
        }
        .privadiGlassCard()
    }
}
