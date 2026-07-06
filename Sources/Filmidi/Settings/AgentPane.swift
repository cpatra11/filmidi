import AppKit
import SwiftUI

struct AgentPane: View {
    @Bindable private var appState = AppState.shared
    @State private var hasQwenKey: Bool = false
    @State private var maskedQwenKey: String = ""
    @State private var qwenDraft: String = ""
    @FocusState private var isQwenFocused: Bool

    @State private var isSigningIn: Bool = false
    @State private var signInError: String?

    @State private var selectedMode: FilmidiMode = .direct

    private let consoleURL = URL(string: "https://www.qwencloud.com")!

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            modePicker
            Divider().overlay(AppTheme.Border.subtleColor)
            switch selectedMode {
            case .direct:
                directKeySection
            case .backend:
                backendSignInSection
            }
            Divider().overlay(AppTheme.Border.subtleColor)
            mcpSection
        }
        .onAppear(perform: refresh)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Connection Mode")
                .font(.system(size: AppTheme.FontSize.md, weight: .medium))
                .foregroundStyle(AppTheme.Text.primaryColor)

            Picker("", selection: $selectedMode) {
                ForEach([FilmidiMode.direct, .backend], id: \.self) { mode in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.label)
                        Text(mode.description)
                            .font(.system(size: AppTheme.FontSize.xs))
                            .foregroundStyle(AppTheme.Text.tertiaryColor)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selectedMode) { _, newValue in
                QwenAccountService.shared.setMode(newValue)
            }
        }
    }

    private var directKeySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.smMd) {
            directHeader
            directKeyField
        }
    }

    private var directHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Qwen Cloud API Key")
                .font(.system(size: AppTheme.FontSize.md, weight: .medium))
                .foregroundStyle(AppTheme.Text.primaryColor)

            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text("Used for AI chat, video generation, image generation, and TTS. Stored in your macOS Keychain.")
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundStyle(AppTheme.Text.tertiaryColor)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: { NSWorkspace.shared.open(consoleURL, configuration: .init(), completionHandler: nil) }) {
                    HStack(spacing: 2) {
                        Text("Get Qwen API key")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: AppTheme.FontSize.xs, weight: .semibold))
                    }
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundStyle(AppTheme.Accent.primary)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
    }

    private var directKeyField: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            SecureField(directPlaceholder, text: $qwenDraft)
                .textFieldStyle(.plain)
                .focused($isQwenFocused)
                .font(.system(size: AppTheme.FontSize.sm, design: .monospaced))
                .foregroundStyle(AppTheme.Text.primaryColor)
                .onSubmit(saveQwenKey)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.smMd)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                        .fill(Color.black.opacity(AppTheme.Opacity.muted))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                        .strokeBorder(
                            isQwenFocused ? AppTheme.Border.primaryColor : AppTheme.Border.subtleColor,
                            lineWidth: AppTheme.BorderWidth.thin
                        )
                )
                .animation(.easeOut(duration: AppTheme.Anim.hover), value: isQwenFocused)

            directTrailingControl
        }
    }

    private var directPlaceholder: String {
        hasQwenKey ? maskedQwenKey : "sk-..."
    }

    @ViewBuilder
    private var directTrailingControl: some View {
        let trimmed = qwenDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            Button("Save", action: saveQwenKey)
                .buttonStyle(.capsule(.prominent, size: .regular))
                .controlSize(.large)
        } else if hasQwenKey {
            Button(action: removeQwenKey) {
                Image(systemName: "trash")
                    .font(.system(size: AppTheme.FontSize.md))
                    .foregroundStyle(AppTheme.Text.secondaryColor)
                    .frame(width: AppTheme.IconSize.md, height: AppTheme.IconSize.md)
            }
            .buttonStyle(.capsule(.secondary, size: .regular))
            .controlSize(.large)
            .help("Remove API key")
        }
    }

    private var backendSignInSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.smMd) {
            backendHeader
            if let email = QwenAccountService.shared.sessionEmail {
                signedInState(email: email)
            } else {
                signInButton
            }
            if let error = signInError {
                Text(error)
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundStyle(AppTheme.Status.errorColor)
            }
        }
    }

    private var backendHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("Filmidi Backend")
                .font(.system(size: AppTheme.FontSize.md, weight: .medium))
                .foregroundStyle(AppTheme.Text.primaryColor)

            Text("Sign in with Google to use the Filmidi backend with your subscription.")
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundStyle(AppTheme.Text.tertiaryColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signInButton: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: AppTheme.FontSize.lg))
                Text(isSigningIn ? "Signing in…" : "Sign in with Google")
            }
            .frame(maxWidth: .infinity)
            .font(.system(size: AppTheme.FontSize.md, weight: .medium))
        }
        .buttonStyle(.capsule(.prominent, size: .regular))
        .controlSize(.large)
        .disabled(isSigningIn)
    }

    private func signedInState(email: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: AppTheme.FontSize.lg))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in")
                        .font(.system(size: AppTheme.FontSize.sm, weight: .medium))
                        .foregroundStyle(AppTheme.Text.primaryColor)
                    Text(email)
                        .font(.system(size: AppTheme.FontSize.sm))
                        .foregroundStyle(AppTheme.Text.tertiaryColor)
                }
            }
            Button(action: signOut) {
                Text("Sign out")
                    .font(.system(size: AppTheme.FontSize.sm))
            }
            .buttonStyle(.capsule(.secondary, size: .regular))
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.smMd)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                .fill(Color.black.opacity(AppTheme.Opacity.muted))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                .strokeBorder(AppTheme.Border.subtleColor, lineWidth: AppTheme.BorderWidth.thin)
        )
    }

    private func refresh() {
        let account = QwenAccountService.shared
        selectedMode = account.mode
        hasQwenKey = account.qwenAPIKey != nil
        maskedQwenKey = account.qwenAPIKey.map(mask) ?? ""
    }

    private func saveQwenKey() {
        let key = qwenDraft.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        qwenDraft = ""
        isQwenFocused = false
        Task { @MainActor in
            await Task.detached(priority: .userInitiated) {
                QwenKeychain.saveKey(key)
            }.value
            refresh()
        }
    }

    private func removeQwenKey() {
        qwenDraft = ""
        Task { @MainActor in
            await Task.detached(priority: .userInitiated) {
                QwenKeychain.deleteKey()
            }.value
            refresh()
        }
    }

    private func signInWithGoogle() {
        isSigningIn = true
        signInError = nil
        Task {
            defer { isSigningIn = false }
            do {
                _ = try await GoogleAuthService.signIn()
                refresh()
            } catch {
                signInError = error.localizedDescription
            }
        }
    }

    private func signOut() {
        GoogleAuthService.signOut()
        signInError = nil
        refresh()
    }

    private func mask(_ key: String) -> String {
        guard key.count > 4 else { return String(repeating: "\u{2022}", count: 32) }
        return String(repeating: "\u{2022}", count: 36) + key.suffix(4)
    }

    private var mcpSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.smMd) {
            mcpHeader
            mcpStatusRow
        }
    }

    private var mcpHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("MCP Server")
                .font(.system(size: AppTheme.FontSize.md, weight: .medium))
                .foregroundStyle(AppTheme.Text.primaryColor)

            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text("Lets external clients like Cursor, Claude Desktop, Claude Code, and Codex edit your timeline.")
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundStyle(AppTheme.Text.tertiaryColor)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: openInstructions) {
                    HStack(spacing: 2) {
                        Text("Setup instructions")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: AppTheme.FontSize.xs, weight: .semibold))
                    }
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundStyle(AppTheme.Accent.primary)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
    }

    private var mcpStatusRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Circle()
                    .fill((appState.mcpService?.isRunning ?? false) ? Color.green : AppTheme.Text.mutedColor)
                    .frame(width: 8, height: 8)

                if appState.mcpService?.isRunning ?? false {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Running on ")
                            .foregroundStyle(AppTheme.Text.secondaryColor)
                        Text("127.0.0.1:\(String(MCPService.port))")
                            .font(.system(size: AppTheme.FontSize.sm, design: .monospaced))
                            .foregroundStyle(AppTheme.Text.primaryColor)
                    }
                } else {
                    Text("Stopped")
                        .foregroundStyle(AppTheme.Text.tertiaryColor)
                }
            }
            .font(.system(size: AppTheme.FontSize.sm))

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { (appState.mcpService?.isRunning ?? false) },
                    set: { appState.setMCPEnabled($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.smMd)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                .fill(Color.black.opacity(AppTheme.Opacity.muted))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                .strokeBorder(AppTheme.Border.subtleColor, lineWidth: AppTheme.BorderWidth.thin)
        )
    }

    private func openInstructions() {
        HelpWindowController.shared.show(tab: .mcp)
    }
}
