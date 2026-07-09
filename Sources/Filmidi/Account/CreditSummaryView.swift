import SwiftUI

struct CreditSummaryView: View {
    enum Style {
        case full   // settings: bigger title + progress bar
        case compact // generation panel header chip
    }

    let style: Style
    @Bindable private var account = AccountService.shared
    @State private var showActions = false

    var body: some View {
        let remaining = account.remainingCredits
        if remaining != .max, remaining >= 0 {
            switch style {
            case .full:
                fullView(remaining: remaining)
            case .compact:
                Button {
                    showActions = true
                } label: {
                    compactView(remaining: remaining)
                }
                .buttonStyle(.plain)
                .help("Manage credits")
                .popover(isPresented: $showActions, arrowEdge: .bottom) {
                    CreditActionsPopover(isPresented: $showActions)
                }
            }
        }
    }

    private func fullView(remaining: Int) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text("\(remaining.formatted()) remaining")
                    .font(.system(size: AppTheme.FontSize.sm, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(barColor(remaining))
                Spacer()
            }
        }
    }

    private func compactView(remaining: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundStyle(barColor(remaining))
            Text(remaining.formatted())
                .font(.system(size: AppTheme.FontSize.xs, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(barColor(remaining))
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(AppTheme.Border.subtleColor, lineWidth: AppTheme.BorderWidth.hairline)
        )
        .help("\(remaining.formatted()) credits remaining")
    }

    private func barColor(_ remaining: Int) -> Color {
        if remaining <= 0 { return .red }
        if remaining < 50 { return .orange }
        return AppTheme.Accent.primary
    }
}

private struct CreditActionsPopover: View {
    @Bindable private var account = AccountService.shared
    @Binding var isPresented: Bool
    @State private var topOffDollars: Int = 20

    private static let popoverWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.smMd) {
            if account.isPaid {
                paidActions
            } else {
                freeActions
            }

            if let error = account.lastError {
                Text(error)
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(width: Self.popoverWidth)
    }

    // MARK: - Free tier

    @ViewBuilder
    private var freeActions: some View {
        sectionCaption("Upgrade to add credits")
        Button { openAccountSettings() } label: {
            Text("Account settings").frame(maxWidth: .infinity)
        }
        .buttonStyle(.capsule(.prominent))
        .controlSize(.small)
    }

    // MARK: - Paid tier

    @ViewBuilder
    private var paidActions: some View {
        sectionCaption("Add credits")
        TopOffField(dollars: $topOffDollars, controlSize: .small, fillWidth: false) {
            account.buyCredits(dollars: topOffDollars)
            isPresented = false
        } trailing: {
            Button { openAccountSettings() } label: {
                Text("Account settings")
            }
            .buttonStyle(.capsule(.secondary))
            .controlSize(.small)
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: AppTheme.FontSize.xs, weight: .medium))
            .foregroundStyle(AppTheme.Text.tertiaryColor)
    }

    private func openAccountSettings() {
        SettingsWindowController.shared.show(tab: .account)
        isPresented = false
    }
}
