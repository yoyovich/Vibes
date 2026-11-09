import Foundation

/// Converts amounts into the base currency using manually entered rates.
struct CurrencyConverter: Hashable, Sendable {
    let baseCode: String
    let rates: [String: Decimal]

    init(baseCode: String, rates: [String: Decimal]) {
        self.baseCode = baseCode
        self.rates = rates
    }

    /// Valid rate for a currency, or nil when it is not set (rates ≤ 0 are never valid).
    func rate(for code: String) -> Decimal? {
        if code == baseCode { return 1 }
        guard let rate = rates[code], rate > 0 else { return nil }
        return rate
    }

    func isRateMissing(for code: String) -> Bool {
        rate(for: code) == nil
    }

    /// Missing rates fall back to 1, the UI flags them with `isRateMissing`.
    func convert(_ amount: Decimal, from code: String) -> Decimal {
        amount * (rate(for: code) ?? 1)
    }

    /// Expresses the stored rates relative to a new base currency.
    /// Rates that can no longer be derived are dropped (they become "not set").
    func rebased(to newBase: String) -> [String: Decimal] {
        guard newBase != baseCode else { return rates.filter { $0.value > 0 } }
        guard let pivot = rate(for: newBase) else { return [:] }
        var result: [String: Decimal] = [:]
        for (code, value) in rates where value > 0 && code != newBase {
            result[code] = (value / pivot).rounded(scale: 6)
        }
        result[baseCode] = (1 / pivot).rounded(scale: 6)
        return result
    }
}

extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
