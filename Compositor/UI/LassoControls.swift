import SwiftUI

struct LassoControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        HStack(spacing: 12) {
            Text(session.tool == .marquee ? "选框" : session.tool == .wand ? "魔棒／对象" : "套索").font(ToolHeaderStyle.titleFont)
            if session.tool == .marquee {
                Picker("形状", selection: Binding(get: { session.marqueeKind }, set: { kind in
                    session.cancelLasso()
                    session.marqueeKind = kind
                })) {
                    ForEach(LassoKind.marqueeChoices, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("按 M 切换矩形与椭圆")
            }
            if session.tool == .wand {
                Picker("模式", selection: Binding(get: { session.wandMode }, set: { mode in
                    session.cancelLasso()
                    session.wandMode = mode
                })) {
                    ForEach(WandMode.allCases, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("按 Tab 切换魔棒与对象选择")
            }
            if session.tool == .lasso {
                Picker("套索", selection: Binding(get: { session.lassoKind }, set: { kind in
                    session.cancelLasso()
                    session.lassoKind = kind
                })) {
                    ForEach(LassoKind.lassoChoices, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("按 L 切换自由套索与多边形套索")
            }
            // Shows held Shift/Option (or an outline's mode) live; clicking sets the choice.
            Picker("模式", selection: Binding(get: { session.displayedSelectionMode },
                                              set: { session.selectionModeChoice = $0 })) {
                ForEach(SelectionMode.allCases, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("按住 Shift 添加，或按住 Option 减去单个轮廓")
            if session.tool == .wand, session.wandMode == .wand { wandControls }
            if session.tool == .wand, session.wandMode == .object { objectSelectionControls }
            // Rectangles snap to whole pixels, so smoothing doesn't apply (as in Photoshop); ellipses curve.
            if session.tool == .lasso || session.tool == .wand || (session.tool == .marquee && session.marqueeKind == .ellipse) {
                Toggle("消除锯齿", isOn: $session.selectionAntialiased)
                    .help(session.tool == .wand && session.wandMode == .object ? "平滑检测到的对象轮廓；关闭后使用原始像素蒙版" : "平滑选区边缘；关闭后保留硬像素边缘")
            }
            Divider().frame(height: 18)
            modifyControl("扩展", amount: $session.selectionExpandAmount) {
                session.expandSelection(by: session.selectionExpandAmount)
            }
            modifyControl("收缩", amount: $session.selectionContractAmount) {
                session.contractSelection(by: session.selectionContractAmount)
            }
            // Softens the selection's edge, as Select → Feather does.
            HStack(spacing: 5) {
                Button("羽化") { session.featherSelection(by: session.selectionFeatherAmount) }
                    .disabled(!session.canModifySelection)
                    .help("按此像素数量渐隐选区边缘")
                TextField("羽化", value: Binding(get: { Double(session.selectionFeatherAmount) },
                                                    set: { session.selectionFeatherAmount = $0.isFinite ? Int(min(250, max(1, $0))) : 2 }),
                          format: .number.precision(.fractionLength(0)))
                    .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(session.selectionFeatherAmount) },
                                change: { session.selectionFeatherAmount = Int(min(250, max(1, $0))) })
                    .unitSuffix("px", scrubValue: $session.selectionFeatherAmount,
                                sensitivity: 1, range: 1...250)
            }
            Spacer(minLength: 0)
            if let selection = session.selection {
                if selection.isEmpty { Text("空选区").foregroundStyle(.secondary) }
                Button("取消选择") { session.deselect() }.disabled(!session.canEditSelection)
            }
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }

    /// Tolerance, sample size, which pixels to read, and whether matches must connect.
    private var wandControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("容差").scrubbable(sensitivity: 1, value: $session.wandSettings.tolerance, range: 0...255)
                TextField("容差", value: Binding(get: { session.wandSettings.tolerance },
                                                      set: { session.wandSettings.tolerance = min(255, max(0, $0)) }),
                          format: .number)
                    .frame(width: 44).textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(session.wandSettings.tolerance) },
                                change: { session.wandSettings.tolerance = Int(min(255, max(0, $0.rounded()))) })
            }
            .help("各颜色通道（0–255）与所单击颜色的差异小于此值时，仍会被选中")
            Picker("取样大小", selection: $session.wandSettings.sampleSize) {
                ForEach(WandSampleSize.allCases, id: \.self) { Text(ChineseUI($0.title)).tag($0) }
            }
            .labelsHidden().fixedSize()
            .help("匹配所单击的单个像素，或其周围像素的平均值")
            Picker("取样", selection: $session.wandSettings.sampleAllLayers) {
                Text("此图层").tag(false)
                Text("所有图层").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("仅读取当前图层的颜色，或按显示效果读取所有可见图层")
            Toggle("连续", isOn: $session.wandSettings.contiguous)
                .help("仅选择与单击位置相连的相似像素；关闭后选择所有位置的相似像素")
        }
    }

    private var objectSelectionControls: some View {
        HStack(spacing: 12) {
            Picker("取样", selection: $session.objectSelectionSettings.sampleAllLayers) {
                Text("此图层").tag(false)
                Text("所有图层").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("仅分析当前图层，或按显示效果分析所有可见图层")
            HStack(spacing: 6) {
                Text("边缘").scrubbable(sensitivity: 1, value: $session.objectSelectionSettings.edgeOffset, range: -10...10)
                TextField("边缘", value: Binding(get: { session.objectSelectionSettings.edgeOffset },
                                                 set: { session.objectSelectionSettings.edgeOffset = min(10, max(-10, $0)) }),
                          format: .number)
                    .frame(width: 40).textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(session.objectSelectionSettings.edgeOffset) },
                                change: { session.objectSelectionSettings.edgeOffset = Int(min(10, max(-10, $0.rounded()))) })
                    .unitSuffix("px")
            }
            // The bar squeezes text before controls, so without this the label and unit collapse to
            // nothing the moment a selection adds its own buttons, leaving an unlabelled number box.
            .fixedSize()
            .help("正值向内收紧检测到的蒙版；负值向外扩展")
        }
    }

    /// A button plus its pixel amount (1–500, default 1); both disabled without a selection.
    private func modifyControl(_ title: String, amount: Binding<Int>, action: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Button(ChineseUI(title), action: action)
            TextField(ChineseUI(title), value: Binding(get: { amount.wrappedValue },
                                            set: { amount.wrappedValue = min(500, max(1, $0)) }),
                      format: .number)
                .frame(width: 40).textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .arrowSteps(value: { Double(amount.wrappedValue) },
                            change: { amount.wrappedValue = Int(min(500, max(1, $0.rounded()))) })
                .unitSuffix("px", scrubValue: amount, sensitivity: 1, range: 1...500)
        }
        .disabled(!session.canModifySelection)
        .help("按此像素数量\(title)选区")
    }
}

/// Tool-rail icon for the Polygonal Lasso: the lasso's loop and rope drawn as straight segments, in the
/// line weight of the SF Symbols beside it.
struct PolygonalLassoToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 18
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            // Laid out like the SF Symbol lasso: a wide loop, a knot below its right side, a short rope.
            var loop = Path()
            loop.addLines([point(1.2, 7.0), point(4.0, 2.4), point(11.8, 1.8), point(16.8, 5.2), point(15.6, 10.4), point(7.0, 11.6)])
            loop.closeSubpath()
            var knot = Path()
            knot.addLines([point(8.9, 10.9), point(13.3, 10.5), point(11.6, 14.5)])
            knot.closeSubpath()
            var rope = Path()
            rope.addLines([point(11.6, 14.5), point(12.9, 17.3)])
            let style = StrokeStyle(lineWidth: 1.4 * unit, lineCap: .round, lineJoin: .round)
            for part in [loop, knot, rope] { context.stroke(part, with: .foreground, style: style) }
        }
        .accessibilityHidden(true)
    }
}

/// Selection modifiers share the filter panels' floating window and control layout.
struct SelectionAmountSheet: View {
    let session: EditorSession
    let operation: EditorSession.SelectionAmountOperation
    @State private var input: String
    @FocusState private var focused: Bool

    init(session: EditorSession, operation: EditorSession.SelectionAmountOperation) {
        self.session = session
        self.operation = operation
        let amount: Int
        switch operation {
        case .expand: amount = session.selectionExpandAmount
        case .contract: amount = session.selectionContractAmount
        case .feather: amount = session.selectionFeatherAmount
        }
        _input = State(initialValue: String(amount))
    }

    private var maximum: Int { operation == .feather ? 250 : 500 }
    private var amount: Int? {
        guard let value = Int(input.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...maximum).contains(value) else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("数量").frame(minWidth: 60, alignment: .leading)
                    .scrubbable(sensitivity: 1,
                                value: Binding<Int>(get: { amount ?? 1 }, set: { input = String($0) }),
                                range: 1...maximum)
                Slider(value: Binding(get: { Double(amount ?? 1) },
                                      set: { input = String(Int($0.rounded())) }),
                       in: 1...Double(maximum), step: 1)
                TextField("数量", text: $input)
                    .frame(width: 56).textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing).focused($focused)
                    .unitSuffix("px")
            }
            Text("输入从 1 到 \(maximum) 的整数像素值。")
                .font(.callout).foregroundStyle(.secondary)
                .opacity(amount == nil ? 1 : 0)
            Divider()
            HStack {
                Button("取消") { session.selectionAmountOperation = nil }
                    .configuredNativeShortcut(.escape)
                Spacer()
                Button("确定") {
                    if let amount { session.confirmSelectionAmount(amount) }
                }
                .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
                .disabled(amount == nil)
            }
        }
        .padding(24).frame(width: 380).fixedSize()
        .onAppear { focused = true }
    }
}

struct ObjectSelectionToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 18
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            let style = StrokeStyle(lineWidth: 1.6 * unit, lineCap: .round, lineJoin: .round)
            for corners in [
                [point(2, 6), point(2, 2), point(6, 2)],
                [point(12, 2), point(16, 2), point(16, 6)],
                [point(16, 12), point(16, 16), point(12, 16)],
                [point(6, 16), point(2, 16), point(2, 12)]
            ] {
                var corner = Path()
                corner.addLines(corners)
                context.stroke(corner, with: .foreground, style: style)
            }
            var cursor = Path()
            cursor.addLines([point(7, 5), point(7, 14), point(9.6, 11.7), point(11.3, 15.3),
                             point(13.2, 14.4), point(11.5, 10.9), point(14.5, 10.9)])
            cursor.closeSubpath()
            context.fill(cursor, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
