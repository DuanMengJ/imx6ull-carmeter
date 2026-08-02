// WarningLights - 12 个 Telltale (指示灯)
//
// 数据来源: VehicleData QML 单例的 12 个 bool 属性 (见 CONTEXT.md)。
// 闪烁 (转向灯/双闪) 由本地 Timer 处理 (grilling: bool + QML 闪烁特例)。
// 资源: mark/<name>_on.png; 全部通过 visible 控制点灭，无暗态 off 图。
//
// PowerOnSelfTest 期间 forceAllOn=true, 12 个 Telltale 全部常亮不闪 (见 ADR-0003)。

import QtQuick
import CarMeter

Item {
    id: lights

    // 闪烁控制 (500ms 切换, 仅对转向灯/双闪)
    property bool blinkOn: false
    // PowerOnSelfTest 期间强制全部常亮
    property bool forceAllOn: false

    width: 800
    height: 480


    Timer {
        interval: 500
        repeat: true
        // PowerOnSelfTest 期间 forceAllOn=true 暂停闪烁 Timer, 省定时器开销 (qt-qml-review)
        running: !lights.forceAllOn
        onTriggered: lights.blinkOn = !lights.blinkOn
    }

    // ── 顶部 8 个 ─────────────────────────────────────────────
    // turnLeft (闪烁, on 图)
    Image {
        x: 10; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/turn_left_on.png"
        visible: lights.forceAllOn || (VehicleData.turnLeft && lights.blinkOn)
        sourceSize.width: 64; sourceSize.height: 40
    }
    // highBeam (单图, 可见性)
    Image {
        x: 65; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/highbeam.png"
        visible: lights.forceAllOn || VehicleData.highBeam
        sourceSize.width: 64; sourceSize.height: 40
    }
    // headLamp (单图 visible 控制)
    Image {
        x: 145; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/headlamp_on.png"
        visible: lights.forceAllOn || VehicleData.headLamp
        sourceSize.width: 64; sourceSize.height: 40
    }
    // fogLamp (单图 visible 控制)
    Image {
        x: 220; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/fog_lamp_on.png"
        visible: lights.forceAllOn || VehicleData.fogLamp
        sourceSize.width: 64; sourceSize.height: 40
    }
    // doorOpen (单图)
    Image {
        x: 540; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/door_open.png"
        visible: lights.forceAllOn || VehicleData.doorOpen
        sourceSize.width: 64; sourceSize.height: 40
    }
    // parking (单图 visible 控制)
    Image {
        x: 610; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/parking_on.png"
        visible: lights.forceAllOn || VehicleData.parking
        sourceSize.width: 64; sourceSize.height: 40
    }
    // safetyBelt (单图 visible 控制)
    Image {
        x: 690; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/safety_belt_on.png"
        visible: lights.forceAllOn || VehicleData.safetyBelt
        sourceSize.width: 64; sourceSize.height: 40
    }
    // turnRight (闪烁)
    Image {
        x: 750; y: 9
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/turn_right_on.png"
        visible: lights.forceAllOn || (VehicleData.turnRight && lights.blinkOn)
        sourceSize.width: 64; sourceSize.height: 40
    }

    // ── 底部 4 个 ─────────────────────────────────────────────
    // absBrake (单图 visible 控制)
    Image {
        x: 33; y: 431
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/abs_on.png"
        visible: lights.forceAllOn || VehicleData.absBrake
        sourceSize.width: 64; sourceSize.height: 40
    }
    // emergencyLamp (闪烁)
    Image {
        x: 158; y: 431
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/emergency_lamp_on.png"
        visible: lights.forceAllOn || (VehicleData.emergencyLamp && lights.blinkOn)
        sourceSize.width: 64; sourceSize.height: 40
    }
    // engine (单图 visible 控制)
    Image {
        x: 588; y: 431
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/engine_on.png"
        visible: lights.forceAllOn || VehicleData.engine
        sourceSize.width: 64; sourceSize.height: 40
    }
    // enginoil (单图 visible 控制)
    Image {
        x: 723; y: 431
        source: "qrc:/qt/qml/CarMeter/resources/images/car/mark/enginoil_on.png"
        visible: lights.forceAllOn || VehicleData.engineOil
        sourceSize.width: 64; sourceSize.height: 40
    }
}
