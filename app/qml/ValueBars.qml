// ValueBars — 对应 CarMeterWidget::drawRects() 的左右电量条
//
// 源码语义 (carmeterwidget.cpp):
//   for (int i = 0; i < m_nLeftPower; i++)
//       painter->drawPixmap(s_leftPoint[i], QPixmap(":/images/car/left/left_value_%1.png").arg(i));
//
// drawPixmap(QPointF, QPixmap) 是「左上角对齐 + 按 PNG 原始尺寸绘制」,
// 不做任何缩放 — 22 张 PNG 宽度各不相同 (52..85px, 高恒为 21px),
// 所以 Image 不设 width/height, 让其取 implicit 尺寸。

pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: bars

    width: 800
    height: 480

    // CarMeterWidget::m_nLeftPower / m_nRightPower
    property int leftPower: 0
    property int rightPower: 0

    // carmeterwidget.cpp: static const QPointF s_leftPoint[]
    readonly property var leftPoints: [
        Qt.point(56, 351), Qt.point(55, 327), Qt.point(55, 303), Qt.point(56, 280),
        Qt.point(57, 257), Qt.point(61, 233), Qt.point(67, 210), Qt.point(75, 187),
        Qt.point(85, 163), Qt.point(99, 140), Qt.point(115, 116)
    ]

    // carmeterwidget.cpp: static const QPointF s_rightPoint[]
    readonly property var rightPoints: [
        Qt.point(660, 351), Qt.point(671, 327), Qt.point(678, 303), Qt.point(683, 280),
        Qt.point(684, 257), Qt.point(682, 233), Qt.point(678, 210), Qt.point(671, 187),
        Qt.point(662, 163), Qt.point(648, 140), Qt.point(630, 116)
    ]

    Repeater {
        model: bars.leftPower

        Image {
            required property int index

            x: bars.leftPoints[index].x
            y: bars.leftPoints[index].y
            source: "qrc:/qt/qml/CarMeter/resources/images/car/left_value_" + index + ".png"
            // 22 张电量条 PNG 宽 52~85 高 21 (PIL 实测), sourceSize 让 Qt 跳过全分辨率解码
            sourceSize.width: 85
            sourceSize.height: 21
        }
    }

    Repeater {
        model: bars.rightPower

        Image {
            required property int index

            x: bars.rightPoints[index].x
            y: bars.rightPoints[index].y
            source: "qrc:/qt/qml/CarMeter/resources/images/car/right_value_" + index + ".png"
            sourceSize.width: 85
            sourceSize.height: 21
        }
    }
}
