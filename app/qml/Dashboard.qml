// Dashboard - 对应 CarMeterWidget
//
// 逐层复刻 carmeterwidget.cpp::paintEvent 的绘制顺序:
//   1. drawPixmap(rect, ic_background.png)  背景
//   2. drawRects()                          左右段条
//   3. drawMarIcons()                       12 个指示灯 (Telltale)
//   4. drawValue()                          表盘 + 指针 + 文字
//
// 基准画布 800x480。板端 LCD 即 800x480, 故 QtWidgetBase 的
// m_scaleX / m_scaleY 恒为 1.0 - 源码里的坐标即物理像素坐标。
//
// 数据来源: VehicleData QML 单例 (MockDataSource -> VehicleData, 见 ADR-0004)。
// 原 Timer 模拟已删, 仪表状态全部由 VehicleData 驱动。
//
// PowerOnSelfTest (见 CONTEXT.md / ADR-0003): 启动时 2s 自检动效。
// bootProgress 0->1 线性 2s, bootPhase 三角波 0->1->0 (顶点在 1.0s)。
// 动效期间 bootAnimActive=true, speed/leftPower/rightPower 与 telltale 用
// boot 派生值覆盖 VehicleData 绑定; 结束切回 VehicleData。

import QtQuick
import CarMeter

Item {
    id: dashboard

    // ── PowerOnSelfTest ───────────────────────────────────────
    property real bootProgress
    // 动效进行中 bootProgress<1; 到达 1 时 bootAnimActive 自动变 false (声明式, 无需 onFinished)
    readonly property bool bootAnimActive: bootProgress < 1.0
    // 动效结束 (bootProgress 到达 1.0, bootAnimActive 翻 false) 立刻调 mock.start()
    // 与 WarningLights.forceAllOn 翻 false 同一帧; mock 同步设 VehicleData, 无视觉跳变
    onBootAnimActiveChanged: {
        if (!bootAnimActive)
            mock.start()
    }
    // 三角波: 0->1->0, 顶点在 bootProgress=0.5 (动效中点)。条件表达式避免 hot binding 里的函数调用。
    readonly property real bootPhase: bootProgress <= 0.5 ? bootProgress * 2 : 2 - bootProgress * 2
    // int property 隐式截断 real, 避免 Math.round 在 hot binding 里每帧调用 (qt-qml-review)
    readonly property int bootSpeed: bootPhase * 180
    // 11.4 非 11: int 截断 max 仍 11, 但满段持续约 3 帧而非顶点 1 帧, 到顶肉眼可见
    readonly property int bootPower: bootPhase * 11.4

    width: 800
    height: 480

    NumberAnimation on bootProgress {
        from: 0
        to: 1
        duration: 3000
    }

    // 1. 背景
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/CarMeter/resources/images/car/background.png"
        sourceSize.width: 800
        sourceSize.height: 480
        fillMode: Image.Stretch
    }

    // 2. drawRects() - leftPower/rightPower
    ValueBars {
        anchors.fill: parent
        leftPower: dashboard.bootAnimActive ? dashboard.bootPower : VehicleData.leftPower
        rightPower: dashboard.bootAnimActive ? dashboard.bootPower : VehicleData.rightPower
    }

    // 3. drawMarIcons() - 12 个 Telltale (WarningLights 内部绑 VehicleData)
    WarningLights {
        anchors.fill: parent
        forceAllOn: dashboard.bootAnimActive
    }

    // 4. drawValue() - speed
    SpeedIndicator {
        anchors.fill: parent
        speed: dashboard.bootAnimActive ? dashboard.bootSpeed : VehicleData.speed
    }
}
