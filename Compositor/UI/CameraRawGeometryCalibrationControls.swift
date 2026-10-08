import AppKit
import SwiftUI

struct CameraRawGeometryControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("竖直校正").font(.subheadline)
            Picker("竖直校正", selection: uprightBinding) {
                ForEach(CameraRawUprightMode.allCases, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .help("“关闭”保持原图不变；“引导”根据您在图像上绘制的线条进行校正。")
            if raw.geometry.upright == .guided {
                Button {
                    session.filterEdit?.drawingCameraRawGeometryGuide.toggle()
                    session.brushRevision += 1
                } label: {
                    Label("绘制参考线", systemImage: "line.diagonal")
                }
                .help("在预览上绘制两条或更多应为水平或垂直的线。")
                .tint(session.filterEdit?.drawingCameraRawGeometryGuide == true ? Color.accentColor : Color.secondary)
                if session.filterEdit?.drawingCameraRawGeometryGuide == true {
                    Text("在图层上拖动添加参考线，至少绘制两条。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !raw.geometry.guides.isEmpty {
                    Button("清除参考线") {
                        update { $0.cameraRaw.geometry.guides = [] }
                    }
                    .help("移除全部参考线。")
                }
            }
            Picker("投影", selection: binding(\.projection)) {
                ForEach(CameraRawProjection.allCases, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
            }
            .help("透视允许较强的梯形校正；直线投影的变形较柔和。")
            geometrySlider("垂直", \.vertical, help: "朝中心方向校正垂直线。")
            geometrySlider("水平", \.horizontal, help: "朝中心方向校正水平线。")
            geometrySlider("旋转", \.rotate, range: CameraRawGeometrySettings.rotateRange, help: "围绕图像中心旋转。")
            geometrySlider("纵横比", \.aspect, help: "相对于高度拉伸宽度。")
            geometrySlider("缩放", \.scale, help: "在画框内缩放变换后的图像。")
            geometrySlider("水平偏移", \.offsetX, help: "向左或向右移动图像。")
            geometrySlider("垂直偏移", \.offsetY, help: "向上或向下移动图像。")
            Toggle("约束裁切", isOn: binding(\.constrainCrop))
                .help("变换后裁切空白边缘，并使结果重新适合画框。")
        }
    }

    private var uprightBinding: Binding<CameraRawUprightMode> {
        Binding(get: { raw.geometry.upright }, set: { mode in
            update { $0.cameraRaw.geometry.upright = mode }
            if mode != .guided { session.filterEdit?.drawingCameraRawGeometryGuide = false }
        })
    }

    private func binding<T>(_ key: WritableKeyPath<CameraRawGeometrySettings, T>) -> Binding<T> {
        Binding(get: { raw.geometry[keyPath: key] }, set: { value in update { $0.cameraRaw.geometry[keyPath: key] = value } })
    }

    private func geometrySlider(_ title: String, _ key: WritableKeyPath<CameraRawGeometrySettings, Double>,
                                range: ClosedRange<Double> = CameraRawGeometrySettings.toneRange, help: String) -> some View {
        let value = raw.geometry[keyPath: key]
        return HStack(spacing: 10) {
            Text(ChineseUI(title)).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(ChineseUI(help))
                .scrubbable(sensitivity: 1,
                            value: Binding(get: { raw.geometry[keyPath: key] },
                                           set: { newValue in update { $0.cameraRaw.geometry[keyPath: key] = newValue } }), range: range)
            CameraRawSlider(value: value, range: range, track: .plain, help: help,
                            onChange: { rawValue in update { $0.cameraRaw.geometry[keyPath: key] = rawValue.rounded() } },
                            onReset: { update { $0.cameraRaw.geometry[keyPath: key] = 0 } })
            TextField(ChineseUI(title), value: Binding(get: { raw.geometry[keyPath: key] },
                                            set: { newValue in update { $0.cameraRaw.geometry[keyPath: key] = newValue } }),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(ChineseUI(help))
        }
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}

struct CameraRawCalibrationControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("处理版本", selection: binding(\.process)) {
                ForEach(CameraRawProcessVersion.allCases, id: \.self) { Text(ChineseUI($0.rawValue)).tag($0) }
            }
            .help("设置下方校准滑块的应用强度。版本 6 为当前默认版本。")
            Text(ChineseUI(raw.calibration.process.summary))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .help(ChineseUI(raw.calibration.process.summary))
            Text("阴影").font(.subheadline)
            calibrationSlider("色调", \.shadowTint, help: "向最暗色调添加绿色或洋红色。")
            Text("红原色").font(.subheadline)
            calibrationSlider("色相", \.redHue, help: "偏移红色的解释方式。")
            calibrationSlider("饱和度", \.redSaturation, help: "增强或减弱红原色。")
            Text("绿原色").font(.subheadline)
            calibrationSlider("色相", \.greenHue, help: "偏移绿色的解释方式。")
            calibrationSlider("饱和度", \.greenSaturation, help: "增强或减弱绿原色。")
            Text("蓝原色").font(.subheadline)
            calibrationSlider("色相", \.blueHue, help: "偏移蓝色的解释方式。")
            calibrationSlider("饱和度", \.blueSaturation, help: "增强或减弱蓝原色。")
        }
    }

    private func binding<T>(_ key: WritableKeyPath<CameraRawCalibrationSettings, T>) -> Binding<T> {
        Binding(get: { raw.calibration[keyPath: key] }, set: { value in update { $0.cameraRaw.calibration[keyPath: key] = value } })
    }

    private func calibrationSlider(_ title: String, _ key: WritableKeyPath<CameraRawCalibrationSettings, Double>, help: String) -> some View {
        let value = raw.calibration[keyPath: key]
        return HStack(spacing: 10) {
            Text(ChineseUI(title)).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(ChineseUI(help))
                .scrubbable(sensitivity: 1,
                            value: Binding(get: { raw.calibration[keyPath: key] },
                                           set: { newValue in update { $0.cameraRaw.calibration[keyPath: key] = newValue } }),
                            range: CameraRawCalibrationSettings.toneRange)
            CameraRawSlider(value: value, range: CameraRawCalibrationSettings.toneRange, track: .plain, help: help,
                            onChange: { rawValue in update { $0.cameraRaw.calibration[keyPath: key] = rawValue.rounded() } },
                            onReset: { update { $0.cameraRaw.calibration[keyPath: key] = 0 } })
            TextField(ChineseUI(title), value: Binding(get: { raw.calibration[keyPath: key] },
                                            set: { newValue in update { $0.cameraRaw.calibration[keyPath: key] = newValue } }),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(ChineseUI(help))
        }
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}
