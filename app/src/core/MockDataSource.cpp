#include "MockDataSource.h"
#include "VehicleData.h"
#include <QDateTime>

namespace {
    constexpr int TICK_MS = 50;
    constexpr int RAMP_DURATION_MS = 2000;
    constexpr int OSC_LEG_MS = 2000;
    constexpr int POWER_TARGET = 11;
    constexpr int SPEED_TARGET = 180;
    constexpr int SAFETY_BELT_MS = 4000;   // 安全带灯亮 4s 后熄灭
}

MockDataSource::MockDataSource(VehicleData *vehicle, QObject *parent)
    : QObject(parent)
    , m_vehicle(vehicle)
{
    Q_ASSERT(m_vehicle);

    m_timer.setInterval(TICK_MS);
    connect(&m_timer, &QTimer::timeout, this, &MockDataSource::onTick);
    m_safetyBeltTimer.setSingleShot(true);
    connect(&m_safetyBeltTimer, &QTimer::timeout, this, &MockDataSource::onSafetyBeltOff);
    // 不在这里 start(); 等 QML 在 bootAnimActive=false 时调 start()
}

void MockDataSource::start()
{
    if (m_started) return;
    m_started = true;
    m_phase = Phase::RampUp;
    m_phaseStartMs = QDateTime::currentMSecsSinceEpoch();
    applyTelltales();
    m_timer.start();
}

void MockDataSource::applyTelltales()
{
    // 转向灯: 双开 -> WarningLights 的 blinkOn Timer 自动让 turnLeft/turnRight 同步闪烁
    m_vehicle->setTurnLeft(true);
    m_vehicle->setTurnRight(true);
    // 安全带灯: 亮 4s 后熄灭
    m_vehicle->setSafetyBelt(true);
    m_safetyBeltTimer.start(SAFETY_BELT_MS);
    // 其余所有 TT 保持熄灭（不写入）
}

void MockDataSource::onSafetyBeltOff()
{
    m_vehicle->setSafetyBelt(false);
}

void MockDataSource::onTick()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 t = now - m_phaseStartMs;

    switch (m_phase) {
    case Phase::Idle:
        return;

    case Phase::RampUp:
        if (t >= RAMP_DURATION_MS) {
            // 切到 Oscillate 瞬间 flush 一次满状态, 保证 180/11 一定写出去
            m_phase = Phase::Oscillate;
            m_phaseStartMs = now;
            m_vehicle->setSpeed(SPEED_TARGET);
            m_vehicle->setLeftPower(POWER_TARGET);
            m_vehicle->setRightPower(POWER_TARGET);
            return;
        }
        onTickRampUp(t);
        break;

    case Phase::Oscillate:
        onTickOscillate(t);
        break;
    }
}

void MockDataSource::onTickRampUp(qint64 elapsedMs)
{
    const qreal progress = elapsedMs / qreal(RAMP_DURATION_MS);   // [0, 1)
    const int speed = int(SPEED_TARGET * progress);               // 0..179
    const int power = int(POWER_TARGET * progress + 0.5);         // 0..11 (round-half-up)
    m_vehicle->setSpeed(speed);
    m_vehicle->setLeftPower(power);
    m_vehicle->setRightPower(power);
}

void MockDataSource::onTickOscillate(qint64 elapsedMs)
{
    constexpr qint64 period = 2 * OSC_LEG_MS;    // 4000 ms
    const qint64 phase = elapsedMs % period;       // [0, 4000)
    int speed;
    if (phase < OSC_LEG_MS) {
        // 前 2s: 180 → 0 (接 RampUp 末值)
        speed = int(SPEED_TARGET * (1.0 - phase / qreal(OSC_LEG_MS)));
    } else {
        // 后 2s: 0 → 180
        speed = int(SPEED_TARGET * ((phase - OSC_LEG_MS) / qreal(OSC_LEG_MS)));
    }
    m_vehicle->setSpeed(speed);
    // power 锁死 11: Oscillate 阶段不调用 setLeftPower/setRightPower
}
