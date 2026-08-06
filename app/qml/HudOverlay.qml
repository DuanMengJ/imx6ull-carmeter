// HudOverlay - 屏幕 HUD 调试层 (FPS + 进程 CPU 占用), 仅开发调试用
//
// 开关: 环境变量 CARMETER_HUD 非空即开 (main.cpp 读取 -> 上下文属性 hudEnabled)。
//       注意: 上下文属性无变更通知, 此开关是"一次性"的 —— Loader active 在
//       实例化时求值一次, 运行时不可切换。
// 数据: C++ HudMonitor (上下文属性 hudMonitor, afterFrameEnd 计数 + /proc 解析)。
// 几何: 由 Dashboard 的 Loader 显式给定 (240x40, 顶部 telltale 排空档
//       x=290..530, y=9..49); 本组件内部一律锚定, 不自带坐标 —— Qt Loader
//       尺寸规则会把显式尺寸的 Loader 内 item resize 到 Loader 大小。
// 半透明黑底 + 白字, 单行 "FPS 20  CPU 45%"; 中文字体与 SpeedIndicator.qml:225 一致。
//
// 依赖前置: main.cpp 必须在 loadFromModule 之前注入 hudEnabled/hudMonitor
//       (关闭时注入 null)。fps/cpuPercent 的 typeof+null 双防御仅兜底
//       Loader 门控被绕过 (直接实例化) 或上下文未注入的场景。

import QtQuick

Item {
    id: root

    // 防御式读取: 上下文属性未注入 (undefined) 或为 null (关闭状态) 时显示 0
    readonly property int fps: typeof hudMonitor === "undefined" || hudMonitor === null
        ? 0 : hudMonitor.fps
    readonly property int cpuPercent: typeof hudMonitor === "undefined" || hudMonitor === null
        ? 0 : hudMonitor.cpuPercent

    // 半透明底, 盖住背景不影响可读性
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.5
        radius: 3
    }

    Text {
        anchors.centerIn: parent
        color: "white"
        text: "FPS " + root.fps + "  CPU " + root.cpuPercent + "%"
        // 纯 ASCII 调试文本: 显式 PlainText 避免 AutoText 对 '&'/'<' 的
        // rich text 嗅探; preferShaping 跳过无必要的文本整形
        textFormat: Text.PlainText
        font {
            family: "WenQuanYi Zen Hei"
            pixelSize: 22                       // 22px < 40px 高, 单行容纳
            preferShaping: false
        }
    }
}
