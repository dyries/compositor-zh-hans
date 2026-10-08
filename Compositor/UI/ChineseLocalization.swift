import Foundation

// Localize display strings only. Enum raw values and shortcut IDs remain stable.
nonisolated func ChineseUI(_ value: String) -> String {
    let translated = NSLocalizedString(value, tableName: nil, bundle: .main, value: value, comment: "")
    if translated != value { return translated }
    if value.hasPrefix("Color Picker ("), value.hasSuffix(")") {
        let name = String(value.dropFirst("Color Picker (".count).dropLast())
        return ChineseUIFormat("Color Picker (%@)", ChineseUI(name))
    }
    return value
}

nonisolated func ChineseUIFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: ChineseUI(key), locale: Locale(identifier: "zh_Hans_CN"), arguments: arguments)
}

nonisolated func ChineseHistoryName(_ value: String) -> String {
    let translated = ChineseUI(value)
    if translated != value { return translated }
    for prefix in ["New ", "Edit "] where value.hasPrefix(prefix) && value.hasSuffix(" Adjustment") {
        let name = String(value.dropFirst(prefix.count).dropLast(" Adjustment".count))
        return ChineseUIFormat(prefix + "%@ Adjustment", ChineseUI(name))
    }
    for prefix in ["Add ", "Cancel ", "Edit ", "Copy ", "Hide ", "Show ", "Remove "] where value.hasPrefix(prefix) {
        return ChineseUIFormat(prefix + "%@", ChineseUI(String(value.dropFirst(prefix.count))))
    }
    return value
}
