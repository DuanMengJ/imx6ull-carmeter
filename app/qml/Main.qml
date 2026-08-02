// CarMeter 主窗口
// 800x480 全屏仪表盘入口 — Qt 6 + LinuxFB + 软件渲染
//
// 本文件仅做 bootstrap: 建窗口 + 挂 Dashboard。
// 全部仪表状态与绘制在 Dashboard.qml 及其子组件中。

import QtQuick

Window {
    id: rootWindow

    // CarMeter 的基准画布
    width: 800
    height: 480
    visible: true
    color: "black"

    // 板端无边框全屏; 桌面保留标题栏
    flags: embeddedMode ? Qt.FramelessWindowHint : Qt.Window

    title: qsTr("CarMeter")

    Dashboard {
        anchors.fill: parent
    }
}
