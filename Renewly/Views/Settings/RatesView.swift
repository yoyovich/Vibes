import SwiftData
import SwiftUI

/// Manual exchange rates: one unit of each used currency in the base currency.
struct RatesView: View {
    let codes: [String]
    @Environment(\.currencyConverter) private var converter

    var body: some View {
        Form {
            if codes.isEmpty {
                ContentUnavailableView(
                    "No other currencies",
                    systemImage: "dollarsign.arrow.circlepath",
                    description: Text("Rates are only needed for subscriptions in a currency other than the base one.")
                )
            } else {
                Section {
                    ForEach(codes, id: \.self) { code in
                        RateRow(code: code, baseCode: converter.baseCode, current: converter.rate(for: code))
                    }
                } footer: {
                    Text("Until a rate is set, the subscription is converted at 1 and marked “Rate not set”.")
                }
            }
        }
        .navigationTitle("Exchange rates")
    }
}

private struct RateRow: View {
    let code: String
    let baseCode: String
    let current: Decimal?

    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @State private var text = ""
    @State private var error: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    label
                    Spacer(minLength: 8)
                    field.frame(maxWidth: 140)
                }
                VStack(alignment: .leading) {
                    label
                    field
                }
            }
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if current == nil {
                RateMissingBadge()
            }
        }
        .onAppear {
            text = current.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...6))) } ?? ""
        }
        .onChange(of: text) { commit() }
    }

    private var label: some View {
        Text("1 \(code) =")
            .font(.body.monospacedDigit())
    }

    private var field: some View {
        HStack {
            TextField("Not set", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(Text("Rate of \(code) in \(baseCode)"))
            Text(baseCode)
                .foregroundStyle(.secondary)
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let store = DataStore(context: context, errors: errors)
        if trimmed.isEmpty {
            error = nil
            store.setRate(nil, for: code)
            store.save()
            return
        }
        guard let value = AmountParser.parse(trimmed) else {
            error = "Enter a number, for example 0.92 or 0,92."
            return
        }
        guard value > 0 else {
            error = "The rate must be greater than zero."
            return
        }
        error = nil
        store.setRate(value, for: code)
        store.save()
    }
}
