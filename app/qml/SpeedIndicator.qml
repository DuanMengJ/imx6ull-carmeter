// SpeedIndicator
// 绘制顺序:
//   Layer 1  表缘 270° 底弧
//   Layer 2  主进度扇面 (对角线性渐变)
//   Layer 3  进度弧外缘亮边
//   指针     point_hand.png 绕枢轴旋转
//   Layer 4  枢轴径向辉光   <- 注意在指针「之上」
//   文字     速度数字 + 总里程

import QtQuick
import QtQuick.Shapes
import CarMeter

Item {
    id: speedInd

    property int speed: 0

    width: 800
    height: 480

    readonly property real dialCenterX: 400
    readonly property real dialCenterY: 231
    readonly property real dialRadius: 153
    readonly property real edgeRadius: 151
    readonly property real arcStartAngle: 135

    readonly property real arcSweepAngle: speedInd.speed / 180 * 271

    readonly property real pointerAngle: speedInd.speed / 180 * 270 - 134

    // ── 高速警戒模式（≥130 km/h，带 4km/h 滞回） ──────────────────────
    // 加速到 warningThresholdHigh 触发红色警戒，
    // 减速到 warningThresholdLow 解除，避免临界抖动。

    readonly property int warningThresholdHigh: 132  // 加速触发阈值
    readonly property int warningThresholdLow:  128  // 减速解除阈值

    // 警戒状态标志（由 onSpeedChanged 命令式维护，带滞回）
    property bool isWarning: false

    onSpeedChanged: {
        if (speedInd.speed >= speedInd.warningThresholdHigh)
            speedInd.isWarning = true
        else if (speedInd.speed <= speedInd.warningThresholdLow)
            speedInd.isWarning = false
        // 中间区间保持当前状态不变
    }

    // 组件完成时校准一次，确保 isWarning 与初始 speed 一致
    // （避免 speed 初始值 ≥132 时第一帧才翻转造成的瞬态动画）
    Component.onCompleted: {
        if (speedInd.speed >= speedInd.warningThresholdHigh)
            speedInd.isWarning = true
        else if (speedInd.speed <= speedInd.warningThresholdLow)
            speedInd.isWarning = false
    }

    // ── 调色板（蓝色常态 / 红色警戒，通过 isWarning 切换） ─────────────
    // 蓝色基准: #7AC9F0     红色基准: #FF3B30
    // 各层 alpha 百分比一一对应，只换色相，保持视觉层次一致
    // ColorAnimation 实现 200ms 平滑过渡

    property color arcFillStartColor:  // Layer 2 扇面起点 α≈5%
        speedInd.isWarning ? "#0DFF3B30" : "#0D7AC9F0"
    Behavior on arcFillStartColor { ColorAnimation { duration: 200 } }

    property color arcFillEndColor:  // Layer 2 扇面终点 α≈55%
        speedInd.isWarning ? "#8CFF3B30" : "#8C7AC9F0"
    Behavior on arcFillEndColor { ColorAnimation { duration: 200 } }

    property color edgeStrokeColor:  // Layer 3 外缘亮边 α≈78%
        speedInd.isWarning ? "#C7FFB0A8" : "#c7c7ecfa"
    Behavior on edgeStrokeColor { ColorAnimation { duration: 200 } }

    property color glowInnerColor:  // Layer 4 辉光内圈 α≈43%
        speedInd.isWarning ? "#6EFFB0A8" : "#6EC8E8FA"
    Behavior on glowInnerColor { ColorAnimation { duration: 200 } }

    property color glowOuterColor:  // Layer 4 辉光外圈 α=0%
        speedInd.isWarning ? "#00FF3B30" : "#007AC9F0"
    Behavior on glowOuterColor { ColorAnimation { duration: 200 } }

    // Layer 1: 表缘 270° 极淡描边 — 独立 Shape, 不依赖 speed, 整局不重绘
    // QPen(QColor(122,201,240,70), 1.0, SolidLine, RoundCap)
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: "#467AC9F0"
            strokeWidth: 1
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: speedInd.dialCenterX
                centerY: speedInd.dialCenterY
                radiusX: speedInd.dialRadius
                radiusY: speedInd.dialRadius
                startAngle: speedInd.arcStartAngle
                sweepAngle: 270
            }
        }
    }

    // Layer 2+3: 进度扇 + 进度弧外缘亮边 — 依赖 arcSweepAngle, 跟 speed 每帧变
    Shape {
        anchors.fill: parent

        // Layer 2: 主进度扇面 (Qt::NoPen + QLinearGradient)
        // 渐变端点在源码里是 painter 局部坐标 (-153,-153)→(153,153),
        // translate(400,240) 后即绝对 (247,87)→(553,393)。
        // drawPie 是闭合扇形: 圆心 → 弧起点 → 弧 → 回圆心。
        // 颜色随 isWarning 在蓝/红之间平滑切换（200ms 过渡）。
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 247
                y1: 87
                x2: 553
                y2: 393

                GradientStop { position: 0; color: speedInd.arcFillStartColor }
                GradientStop { position: 1; color: speedInd.arcFillEndColor }
            }

            startX: speedInd.dialCenterX
            startY: speedInd.dialCenterY

            PathAngleArc {
                centerX: speedInd.dialCenterX
                centerY: speedInd.dialCenterY
                radiusX: speedInd.dialRadius
                radiusY: speedInd.dialRadius
                startAngle: speedInd.arcStartAngle
                sweepAngle: speedInd.arcSweepAngle
                // false = 从当前点(圆心)拉一条半径到弧起点, 而不是 moveTo
                moveToStart: false
            }

            PathLine {
                x: speedInd.dialCenterX
                y: speedInd.dialCenterY
            }
        }

        // Layer 3: 进度弧外缘锐边
        // QPen(QColor(200,232,250,200), 2.0, SolidLine, RoundCap) + setCosmetic(true)
        // cosmetic 表示线宽不随 painter scale 缩放; 板端 scale 恒为 1.0, 故等价于 strokeWidth: 2。
        // 颜色随 isWarning 在蓝/红之间平滑切换（200ms 过渡）。
        ShapePath {
            strokeColor: speedInd.edgeStrokeColor
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: speedInd.dialCenterX
                centerY: speedInd.dialCenterY
                radiusX: speedInd.edgeRadius
                radiusY: speedInd.edgeRadius
                startAngle: speedInd.arcStartAngle
                sweepAngle: speedInd.arcSweepAngle
            }
        }
    }

    // 指针: point_hand.png 实测 34x170
    // 叠加 translate(400,240) 后左上角落在 (383, 87)。
    // 旋转枢轴是 painter 原点 (400,240), 换算到图片自身坐标即 (17, 153)。
    Image {
        x: 383
        y: 87
        width: 34
        height: 170
        sourceSize.width: 34
        sourceSize.height: 170
        source: "qrc:/qt/qml/CarMeter/resources/images/car/point_hand.png"

        transform: Rotation {
            origin.x: 17
            origin.y: 153
            angle: speedInd.pointerAngle
        }
    }

    // Layer 4: 指针枢轴辉光
    // drawEllipse(QPointF(400,240), 16, 16) 是「圆」, 用整圈 PathAngleArc 表达。
    // 颜色随 isWarning 在蓝/红之间平滑切换（200ms 过渡）。
    Shape {
        anchors.fill: parent

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 400
                centerY: 240
                centerRadius: 10
                focalX: 400
                focalY: 240

                GradientStop { position: 0; color: speedInd.glowInnerColor }
                GradientStop { position: 1; color: speedInd.glowOuterColor }
            }

            PathAngleArc {
                centerX: 400
                centerY: 240
                radiusX: 10
                radiusY: 10
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // 速度数字: drawText(321, 333, 120, 92, Qt::AlignCenter, QString::number(m_nSpeed))
    Text {
        x: 321
        y: 333
        width: 120
        height: 92
        text: speedInd.speed
        color: "#F2F4F7"
        font.family: "WenQuanYi Zen Hei"
        font.pixelSize: 62
        font.bold: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // 总里程: drawText(251, 422, 285, 49, Qt::AlignCenter, tr("总里程：546546 km"))
    Text {
        x: 251
        y: 422
        width: 285
        height: 49
        text: qsTr("总里程：%1 km").arg(Math.floor(VehicleData.odometer))
        color: "#F2F4F7"
        font.family: "WenQuanYi Zen Hei"
        font.pixelSize: 29
        font.bold: false
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
