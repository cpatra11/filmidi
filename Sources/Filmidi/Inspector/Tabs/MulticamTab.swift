import SwiftUI

struct MulticamTab: View {
    @Environment(EditorViewModel.self) var editor

    @State private var newSourceName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            sectionHeader("Sources")

            if editor.multicamEngine.sources.isEmpty {
                emptyState
            } else {
                sourceList
            }

            Divider()
                .foregroundStyle(AppTheme.Border.primaryColor)

            addSourceRow

            if editor.multicamEngine.isActive {
                Divider()
                    .foregroundStyle(AppTheme.Border.primaryColor)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Button("Show All Sources") {
                        editor.switchMulticamSource(to: nil)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: AppTheme.FontSize.sm))
                    .foregroundStyle(AppTheme.Text.secondaryColor)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
    }

    private var emptyState: some View {
        Text("No camera angles yet. Add a source to start multicam editing.")
            .font(.system(size: AppTheme.FontSize.xs))
            .foregroundStyle(AppTheme.Text.tertiaryColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sourceList: some View {
        ForEach(editor.multicamEngine.sources) { source in
            sourceRow(source)
        }
    }

    private func sourceRow(_ source: MulticamSource) -> some View {
        let isActive = editor.multicamEngine.activeSourceId == source.id
        return HStack(spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(Color(red: source.colorRed, green: source.colorGreen, blue: source.colorBlue))
                .frame(width: 12, height: 12)

            Text(source.name)
                .font(.system(size: AppTheme.FontSize.sm, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? AppTheme.Text.primaryColor : AppTheme.Text.secondaryColor)
                .lineLimit(1)

            Spacer()

            let count = editor.multicamEngine.clipsForSource(id: source.id).count
            Text("\(count)")
                .font(.system(size: AppTheme.FontSize.xxs))
                .foregroundStyle(AppTheme.Text.tertiaryColor)

            if isActive {
                Image(systemName: "circle.fill")
                    .font(.system(size: AppTheme.FontSize.xxs))
                    .foregroundStyle(AppTheme.Accent.timecodeColor)
            }

            Button {
                editor.switchMulticamSource(to: source.id)
            } label: {
                Image(systemName: isActive ? "video.fill" : "video")
                    .font(.system(size: AppTheme.FontSize.xs))
                    .foregroundStyle(isActive ? AppTheme.Accent.timecodeColor : AppTheme.Text.tertiaryColor)
            }
            .buttonStyle(.plain)
            .help(isActive ? "Active camera" : "Switch to this angle")
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }

    private var addSourceRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Angle name…", text: $newSourceName)
                .textFieldStyle(.plain)
                .font(.system(size: AppTheme.FontSize.sm))
                .foregroundStyle(AppTheme.Text.primaryColor)

            Button("Add") {
                let name = newSourceName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                editor.createMulticamSource(name: name)
                newSourceName = ""
            }
            .buttonStyle(.plain)
            .font(.system(size: AppTheme.FontSize.sm, weight: .medium))
            .foregroundStyle(AppTheme.Accent.primary)
            .disabled(newSourceName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: AppTheme.FontSize.xxs, weight: .semibold))
            .tracking(AppTheme.Tracking.wide)
            .foregroundStyle(AppTheme.Text.mutedColor)
    }
}
