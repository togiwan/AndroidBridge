import AndroidBridgeCore
import AppKit
import SwiftUI

struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Text("AndroidBridge is free and open source. Donations are completely optional, but appreciated if the app saves you time.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                labeledValue("Asset", AndroidBridgeDonationInfo.asset)
                labeledValue("Network", AndroidBridgeDonationInfo.network)

                Text("Wallet Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(AndroidBridgeDonationInfo.address)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            Label(AndroidBridgeDonationInfo.warning, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(AndroidBridgeDonationInfo.address, forType: .string)
                    didCopy = true
                } label: {
                    Label(didCopy ? "Copied" : "Copy Address", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle")
                .font(.largeTitle)
                .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 2) {
                Text("Support AndroidBridge")
                    .font(.title3.weight(.semibold))

                Text("Optional donation via USDT TRC20")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}
