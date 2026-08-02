#include "BuzzerController.h"
#include "VehicleData.h"
#include "GpioManager.h"

namespace {
    constexpr int BUZZER_SPEED_LOW = 5;      // <=5 不响
    constexpr int BUZZER_SPEED_HIGH = 20;    // >20 持续; (5,20] 间歇
    constexpr int BLINK_INTERVAL_MS = 500;   // 间歇周期, 与 WarningLights.qml 闪烁一致
}

BuzzerController::BuzzerController(VehicleData *vehicle, GpioManager *gpio, QObject *parent)
    : QObject(parent)
    , m_vehicle(vehicle)
    , m_gpio(gpio)
{
    Q_ASSERT(m_vehicle);
    Q_ASSERT(m_gpio);

    m_blinkTimer.setInterval(BLINK_INTERVAL_MS);
    connect(&m_blinkTimer, &QTimer::timeout, this, &BuzzerController::onBlinkTick);

    connect(m_vehicle, &VehicleData::safetyBeltChanged, this, &BuzzerController::reevaluate);
    connect(m_vehicle, &VehicleData::speedChanged, this, &BuzzerController::reevaluate);

    reevaluate();  // 启动时按初始值校准一次
}

void BuzzerController::reevaluate()
{
    const bool belt = m_vehicle->safetyBelt();
    const int speed = m_vehicle->speed();

    if (!belt || speed <= BUZZER_SPEED_LOW)
        setOff();
    else if (speed > BUZZER_SPEED_HIGH)
        setContinuous();
    else
        setIntermittent();
}

void BuzzerController::setOff()
{
    m_blinkTimer.stop();
    m_blinkOn = false;
    m_gpio->setBuzzer(false);
}

void BuzzerController::setIntermittent()
{
    // 已在间歇模式不重置, 避免 5-20 区间内 speed 变化打断节奏
    if (!m_blinkTimer.isActive()) {
        m_blinkOn = true;       // 进入间歇先响
        m_gpio->setBuzzer(true);
        m_blinkTimer.start();
    }
}

void BuzzerController::setContinuous()
{
    m_blinkTimer.stop();
    m_blinkOn = true;
    m_gpio->setBuzzer(true);
}

void BuzzerController::onBlinkTick()
{
    m_blinkOn = !m_blinkOn;
    m_gpio->setBuzzer(m_blinkOn);
}
