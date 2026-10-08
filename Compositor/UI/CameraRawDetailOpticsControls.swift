import AppKit
import SwiftUI

struct CameraRawDetailControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("锐化").font(.subheadline)
            sharpenSlider("数量", \.sharpenAmount, range: CameraRawDetailSettings.sharpenAmountRange, decimals: 0, reset: 0,
                          help: "控制锐化强度。")
            sharpenSlider("半径", \.sharpenRadius, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 10,
                          help: "锐化从每个边缘向外延伸的距离（像素）。")
            sharpenSlider("细节", \.sharpenDetail, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 25,
                          help: "强调精细纹理，而非较宽的边缘。")
            sharpenSlider("蒙版", \.sharpenMasking, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                          maskingPreview: true, help: "将锐化限制在较明显的边缘。按住 Option 查看蒙版。")
            Text("降噪").font(.subheadline)
            slider("明亮度", \.noiseLuminance, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                   help: "平滑亮度中的颗粒与杂色。")
            Group {
                slider("明亮度细节", \.noiseLuminanceDetail, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 50,
                       help: "降低明亮度杂色时保留精细纹理。")
                slider("明亮度对比度", \.noiseLuminanceContrast, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                       help: "明亮度平滑后保持局部对比度。")
            }
            .opacity(raw.detail.noiseLuminance > 0 ? 1 : 0.45)
            .disabled(raw.detail.noiseLuminance <= 0)
            slider("颜色", \.noiseColor, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                   help: "平滑彩色斑点。")
            Group {
                slider("颜色细节", \.noiseColorDetail, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 50,
                       help: "降低颜色杂色时保留彩色边缘。")
                slider("颜色平滑度", \.noiseColorSmoothness, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 50,
                       help: "使颜色平滑更柔和或更集中。")
            }
            .opacity(raw.detail.noiseColor > 0 ? 1 : 0.45)
            .disabled(raw.detail.noiseColor <= 0)
        }
    }

    private func sharpenSlider(_ title: String, _ key: WritableKeyPath<CameraRawDetailSettings, Double>, range: ClosedRange<Double>,
                               decimals: Int, reset: Double, maskingPreview: Bool = false, help: String) -> some View {
        let step = pow(10, Double(decimals))
        let value = raw.detail[keyPath: key]
        return HStack(spacing: 10) {
            Text(ChineseUI(title)).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(ChineseUI(help))
                .scrubbable(sensitivity: 1 / step,
                            value: Binding(get: { raw.detail[keyPath: key] },
                                           set: { assignDetail(key, $0, maskingPreview: false) }), range: range)
            CameraRawSlider(value: value, range: range, track: .plain, help: help,
                            onChange: { rawValue in
                                let stepped = (rawValue * step).rounded() / step
                                assignDetail(key, stepped, maskingPreview: maskingPreview)
                            },
                            onReset: { assignDetail(key, reset, maskingPreview: false) })
            TextField(ChineseUI(title), value: Binding(get: { raw.detail[keyPath: key] }, set: { assignDetail(key, $0, maskingPreview: false) }),
                      format: .number.precision(.fractionLength(0...decimals)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(ChineseUI(help))
        }
    }

    private func slider(_ title: String, _ key: WritableKeyPath<CameraRawDetailSettings, Double>, range: ClosedRange<Double>,
                        decimals: Int, reset: Double, help: String) -> some View {
        sharpenSlider(title, key, range: range, decimals: decimals, reset: reset, help: help)
    }

    private func assignDetail(_ key: WritableKeyPath<CameraRawDetailSettings, Double>, _ newValue: Double, maskingPreview: Bool) {
        if maskingPreview {
            session.filterEdit?.cameraRawSharpenMask = NSEvent.modifierFlags.contains(.option)
        } else {
            session.filterEdit?.cameraRawSharpenMask = false
        }
        update { settings in settings.cameraRaw.detail[keyPath: key] = newValue }
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}

struct CameraRawOpticsControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("移除色差", isOn: binding(\.removeChromaticAberration))
                .help("将红色和蓝色色边向中心分离，以减少色边。")
            Toggle("启用镜头配置文件校正", isOn: binding(\.enableLensProfile))
                .help("缺少相机元数据时应用通用配置强度。")
            if raw.optics.enableLensProfile {
                Text("此图层没有镜头元数据。配置滑块调整通用校正强度。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                opticsSlider("畸变", \.profileDistortion, range: CameraRawOpticsSettings.unitRange, reset: 100,
                             help: "配置文件畸变校正的应用程度。")
                opticsSlider("暗角", \.profileVignetting, range: CameraRawOpticsSettings.unitRange, reset: 100,
                             help: "配置文件暗角校正的应用程度。")
            }
            Text("手动").font(.subheadline)
            opticsSlider("畸变", \.distortion, range: CameraRawOpticsSettings.toneRange, reset: 0,
                         help: "校正桶形或枕形弯曲。")
            HStack(spacing: 10) {
                Text("去边").frame(minWidth: CameraRawControls.labelWidth, alignment: .leading)
                    .help("单击紫色或绿色色边，设置其色相范围。")
                Button {
                    session.filterEdit?.samplesDefringe.toggle()
                    session.brushRevision += 1
                } label: {
                    Image(systemName: "eyedropper")
                }
                .buttonStyle(.borderless)
                .tint(session.filterEdit?.samplesDefringe == true ? Color.accentColor : Color.secondary)
                .help("单击紫色或绿色色边，设置其色相范围。")
            }
            if session.filterEdit?.samplesDefringe == true {
                Text("单击图层上的色边，再次单击吸管停止取样。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            opticsSlider("紫色数量", \.purpleAmount, range: CameraRawOpticsSettings.unitRange, reset: 0,
                         help: "减弱紫色色相范围内的紫色色边。")
            hueRange("紫色色相", low: \.purpleHueLow, high: \.purpleHueHigh,
                     help: "紫色去边作用的色相范围。")
            opticsSlider("绿色数量", \.greenAmount, range: CameraRawOpticsSettings.unitRange, reset: 0,
                         help: "减弱绿色色相范围内的绿色色边。")
            hueRange("绿色色相", low: \.greenHueLow, high: \.greenHueHigh,
                     help: "绿色去边作用的色相范围。")
            opticsSlider("暗角", \.vignetteAmount, range: CameraRawOpticsSettings.toneRange, reset: 0,
                         help: "提亮或压暗四角，以校正镜头亮度衰减。")
            opticsSlider("中点", \.vignetteMidpoint, range: CameraRawOpticsSettings.unitRange, reset: 50,
                         help: "将暗角校正范围向内或向外移动。")
        }
    }

    private func binding(_ key: WritableKeyPath<CameraRawOpticsSettings, Bool>) -> Binding<Bool> {
        Binding(get: { raw.optics[keyPath: key] }, set: { newValue in update { $0.cameraRaw.optics[keyPath: key] = newValue } })
    }

    private func opticsSlider(_ title: String, _ key: WritableKeyPath<CameraRawOpticsSettings, Double>, range: ClosedRange<Double>,
                              reset: Double, help: String) -> some View {
        let value = raw.optics[keyPath: key]
        return HStack(spacing: 10) {
            Text(ChineseUI(title)).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(ChineseUI(help))
                .scrubbable(sensitivity: 1,
                            value: Binding(get: { raw.optics[keyPath: key] },
                                           set: { newValue in update { $0.cameraRaw.optics[keyPath: key] = newValue } }), range: range)
            CameraRawSlider(value: value, range: range, track: .plain, help: help,
                            onChange: { rawValue in
                                let stepped = range.lowerBound < 0 ? rawValue : rawValue.rounded()
                                update { $0.cameraRaw.optics[keyPath: key] = stepped }
                            },
                            onReset: { update { $0.cameraRaw.optics[keyPath: key] = reset } })
            TextField(ChineseUI(title), value: Binding(get: { raw.optics[keyPath: key] }, set: { newValue in update { $0.cameraRaw.optics[keyPath: key] = newValue } }),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(ChineseUI(help))
        }
    }

    private func hueRange(_ title: String, low: WritableKeyPath<CameraRawOpticsSettings, Double>,
                          high: WritableKeyPath<CameraRawOpticsSettings, Double>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ChineseUI(title)).font(.caption).foregroundStyle(.secondary).help(ChineseUI(help))
            HStack(spacing: 8) {
                Text("下限").font(.caption2).help("色相范围的起始角度。")
                CameraRawSlider(value: raw.optics[keyPath: low], range: CameraRawOpticsSettings.hueRange, track: .plain,
                                help: "色相范围的起始角度。",
                                onChange: { value in update { $0.cameraRaw.optics[keyPath: low] = value.rounded() } },
                                onReset: { update { $0.cameraRaw.optics[keyPath: low] = title.contains("紫色") ? 270 : 60 } })
                Text("上限").font(.caption2).help("色相范围的结束角度。")
                CameraRawSlider(value: raw.optics[keyPath: high], range: CameraRawOpticsSettings.hueRange, track: .plain,
                                help: "色相范围的结束角度。",
                                onChange: { value in update { $0.cameraRaw.optics[keyPath: high] = value.rounded() } },
                                onReset: { update { $0.cameraRaw.optics[keyPath: high] = title.contains("紫色") ? 310 : 120 } })
            }
        }
        .padding(.leading, CameraRawControls.labelWidth + 10)
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}
