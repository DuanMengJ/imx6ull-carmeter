#include "VehicleData.h"

VehicleData::VehicleData(QObject *parent)
    : QObject(parent)
{
    // odometer 累加定时器: 16ms (沿用原 SpeedIndicator.qml Timer 语义)。
    // distance = speed(km/h) * 16ms = speed * 16/3600000 = speed / 225000 km。
    m_odoTimer.setInterval(16);
    m_odoTimer.start();
    connect(&m_odoTimer, &QTimer::timeout, this, &VehicleData::onOdoTimer);
}

void VehicleData::onOdoTimer()
{
    if (m_speed <= 0)
        return;
    m_odometer += m_speed / 225000.0;
    emit odometerChanged();
}

void VehicleData::setSpeed(int v)
{
    if (m_speed == v)
        return;
    m_speed = v;
    emit speedChanged();
}

void VehicleData::setOdometer(qreal v)
{
    // qFuzzyCompare 对 0 不可靠, 加 1.0 偏移 (OdoStore 恢复时 v 可能为 0)
    if (qFuzzyCompare(m_odometer + 1.0, v + 1.0))
        return;
    m_odometer = v;
    emit odometerChanged();
}

void VehicleData::setLeftPower(int v)
{
    if (m_leftPower == v)
        return;
    m_leftPower = v;
    emit leftPowerChanged();
}

void VehicleData::setRightPower(int v)
{
    if (m_rightPower == v)
        return;
    m_rightPower = v;
    emit rightPowerChanged();
}

// Telltale setters (12 个, 模式相同: 守卫 + 赋值 + emit)
#define DEFINE_TELLTALE_SETTER(NAME, MEMBER, SIGNAL) \
void VehicleData::set##NAME(bool v) \
{ \
    if (MEMBER == v) \
        return; \
    MEMBER = v; \
    emit SIGNAL(); \
}

DEFINE_TELLTALE_SETTER(TurnLeft, m_turnLeft, turnLeftChanged)
DEFINE_TELLTALE_SETTER(TurnRight, m_turnRight, turnRightChanged)
DEFINE_TELLTALE_SETTER(HighBeam, m_highBeam, highBeamChanged)
DEFINE_TELLTALE_SETTER(HeadLamp, m_headLamp, headLampChanged)
DEFINE_TELLTALE_SETTER(FogLamp, m_fogLamp, fogLampChanged)
DEFINE_TELLTALE_SETTER(DoorOpen, m_doorOpen, doorOpenChanged)
DEFINE_TELLTALE_SETTER(Parking, m_parking, parkingChanged)
DEFINE_TELLTALE_SETTER(SafetyBelt, m_safetyBelt, safetyBeltChanged)
DEFINE_TELLTALE_SETTER(AbsBrake, m_absBrake, absBrakeChanged)
DEFINE_TELLTALE_SETTER(EmergencyLamp, m_emergencyLamp, emergencyLampChanged)
DEFINE_TELLTALE_SETTER(Engine, m_engine, engineChanged)
DEFINE_TELLTALE_SETTER(EngineOil, m_engineOil, engineOilChanged)

#undef DEFINE_TELLTALE_SETTER
