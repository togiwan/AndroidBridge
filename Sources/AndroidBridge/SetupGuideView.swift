import AndroidBridgeCore
import SwiftUI

struct SetupGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro

                    ForEach(AndroidBridgeSetupGuide.sections) { section in
                        guideSection(section)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 720, height: 640)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("AndroidBridge Setup Guide")
                    .font(.title3.weight(.semibold))

                Text("ADB kurulumu, USB debugging ve ilk bağlantı adımları")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bu uygulama nasıl çalışır?")
                .font(.headline)

            Text("AndroidBridge telefonun içindeki dosyalara MTP yerine ADB ile erişir. Bu yüzden Mac'te Android Platform-Tools kurulu olmalı, telefonda USB debugging açık olmalı ve ilk bağlantıda telefondaki güven penceresi onaylanmalıdır.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Link(destination: AndroidBridgeSetupGuide.platformToolsURL) {
                    Label("Official Platform-Tools", systemImage: "arrow.up.right.square")
                }

                Link(destination: AndroidBridgeSetupGuide.adbDocsURL) {
                    Label("Official ADB Docs", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    private func guideSection(_ section: SetupGuideSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.headline)

            Text(section.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(section.steps.enumerated()), id: \.element.id) { index, step in
                    guideStep(step, number: index + 1)
                }
            }
        }
    }

    private func guideStep(_ step: SetupGuideStep, number: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))

                Text(step.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let command = step.command {
                    Text(command)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
