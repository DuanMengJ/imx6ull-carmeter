#pragma once

#include <QObject>
#include <QTimer>

class VehicleData;
class GpioManager;

// BuzzerController - 安全带未系告警蜂鸣策略 (见 ADR-0002)。
//
// 监听 VehicleData 的 safetyBelt + speed, 驱动 GpioManager::setBuzzer:
//   safetyBelt off 或 speed <= 5      -> 蜂鸣关闭
//   safetyBelt on  且 5 < speed <= 20 -> 间歇蜂鸣 (500ms 切换)
//   safetyBelt on  且 speed > 20      -> 持续蜂鸣
// PowerOnSelfTest 期间 VehicleData 为 mock 值 (启动瞬间 speed=0/safetyBelt=false), 自然不响。
class BuzzerController : public QObject {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(BuzzerController)

public:
    explicit BuzzerController(VehicleData *vehicle, GpioManager *gpio, QObject *parent = nullptr);

private slots:
    void reevaluate();      // safetyBelt/speed 变化时重新评估模式
    void onBlinkTick();     // 间歇模式 Timer tick

private:
    void setOff();
    void setIntermittent();
    void setContinuous();

    VehicleData *m_vehicle;
    GpioManager *m_gpio;
    QTimer m_blinkTimer;
    bool m_blinkOn = false;
};
