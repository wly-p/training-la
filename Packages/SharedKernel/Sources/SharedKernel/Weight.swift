import Foundation

/// 重量：每筆各自存「輸入當下」的 `{value, unit}`，不做儲存正規化。
///
/// 因此**任何比較／加總都必須先換算**——換算包在型別自己的 `==` / `<` / `+` / `-` 裡，
/// 呼叫端請用運算子，不要拿 `.value` 直接比：那會忽略單位而靜默算錯
/// （100 lb 會被判定成勝過 100 kg）。`.value` 只用於顯示與持久化。
public struct Weight: Codable, Sendable {
    public var value: Double
    public var unit: WeightUnit

    public init(value: Double, unit: WeightUnit) {
        self.value = value
        self.unit = unit
    }
}

public enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg
    case lb

    /// 1 kg 等於多少 lb。換算只有這一個係數，其餘都由它推導。
    static let poundsPerKilogram = 2.20462262185
}

// MARK: - 單位換算

extension Weight {
    /// 換算成指定單位；同單位直接回傳自己（免掉無謂的浮點來回）。
    public func converted(to unit: WeightUnit) -> Weight {
        guard unit != self.unit else { return self }
        switch unit {
        case .kg: return Weight(value: value / WeightUnit.poundsPerKilogram, unit: .kg)
        case .lb: return Weight(value: value * WeightUnit.poundsPerKilogram, unit: .lb)
        }
    }

    /// 換算成公斤的純量。聚合（Σ 重量 × 次數）用得到——那種加總 `Comparable` 幫不上，
    /// 呼叫端要自己先統一單位。
    public var kilograms: Double {
        unit == .kg ? value : value / WeightUnit.poundsPerKilogram
    }

    /// 比較與雜湊的共同基準：公斤取到 1 公克。
    ///
    /// 用「量化成整數」而不是「浮點加 epsilon」，是因為 epsilon 式的相等不具遞移性
    /// （a≈b、b≈c 不保證 a≈c），會讓 `Equatable` / `Hashable` / `Comparable` 三者互相矛盾。
    /// 量化成整數後三個運算由同一個值推導，天然一致；1 公克遠細於任何實際器材，
    /// 又足以吸收 kg→lb→kg 往返的浮點誤差。
    private var grams: Int64 {
        Int64((kilograms * 1000).rounded())
    }
}

// MARK: - Equatable / Hashable / Comparable（一律換算後比較）

extension Weight: Equatable, Hashable, Comparable {
    public static func == (lhs: Weight, rhs: Weight) -> Bool {
        lhs.grams == rhs.grams
    }

    public static func < (lhs: Weight, rhs: Weight) -> Bool {
        lhs.grams < rhs.grams
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(grams)
    }
}

// MARK: - 加減（回傳左運算元的單位）

extension Weight {
    public static func + (lhs: Weight, rhs: Weight) -> Weight {
        Weight(value: lhs.value + rhs.converted(to: lhs.unit).value, unit: lhs.unit)
    }

    public static func - (lhs: Weight, rhs: Weight) -> Weight {
        Weight(value: lhs.value - rhs.converted(to: lhs.unit).value, unit: lhs.unit)
    }
}

// MARK: - 顯示

extension Weight {
    /// 60.0 → "60kg"、62.5 → "62.5kg"。單位照這筆自己的，不替呼叫端決定要不要換算。
    public var displayString: String {
        "\(Self.formatted(value))\(unit.rawValue)"
    }

    /// 數字的顯示格式：60.0 → "60"、62.5 → "62.5"、99.96000000000001 → "99.96"。
    ///
    /// 細級距（例如 0.17）算出來的值會帶浮點雜訊，直接 `String(value)` 會把整串印在畫面上。
    /// 先取到小數三位（＝1 公克，跟比較用的量化同一個精度）再去尾零。
    public static func formatted(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }
        var text = String(format: "%.3f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
