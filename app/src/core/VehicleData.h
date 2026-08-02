#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <QTimer>

// VehicleData - 车辆数据单例，暴露给 QML，由 MockDataSource 驱动。
//
// 数据通路: MockDataSource (主线程 QTimer) -> VehicleData (Q_PROPERTY) -> QML binding
// odometer 由板端 C++ 按 speed 累加 (CAN 已移除, 见 ADR-0004)。
// Telltale 状态为 bool on/off; 闪烁 (转向灯/双闪) 由 QML 本地处理 (见 CONTEXT.md)。

class VehicleData : public QObject {
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT

    // ── 标量属性 ──────────────────────────────────────────────
    Q_PROPERTY(int speed READ speed NOTIFY speedChanged)
    Q_PROPERTY(qreal odometer READ odometer NOTIFY odometerChanged)
    Q_PROPERTY(int leftPower READ leftPower NOTIFY leftPowerChanged)
    Q_PROPERTY(int rightPower READ rightPower NOTIFY rightPowerChanged)

    // ── Telltale (12 个, bool on/off) ─────────────────────────
    // 命名对应 WarningLights.qml 的 12 个唯一指示灯; 转向灯/双闪的闪烁由 QML 处理。
    Q_PROPERTY(bool turnLeft READ turnLeft NOTIFY turnLeftChanged)
    Q_PROPERTY(bool turnRight READ turnRight NOTIFY turnRightChanged)
    Q_PROPERTY(bool highBeam READ highBeam NOTIFY highBeamChanged)
    Q_PROPERTY(bool headLamp READ headLamp NOTIFY headLampChanged)
    Q_PROPERTY(bool fogLamp READ fogLamp NOTIFY fogLampChanged)
    Q_PROPERTY(bool doorOpen READ doorOpen NOTIFY doorOpenChanged)
    Q_PROPERTY(bool parking READ parking NOTIFY parkingChanged)
    Q_PROPERTY(bool safetyBelt READ safetyBelt NOTIFY safetyBeltChanged)
    Q_PROPERTY(bool absBrake READ absBrake NOTIFY absBrakeChanged)
    Q_PROPERTY(bool emergencyLamp READ emergencyLamp NOTIFY emergencyLampChanged)
    Q_PROPERTY(bool engine READ engine NOTIFY engineChanged)
    Q_PROPERTY(bool engineOil READ engineOil NOTIFY engineOilChanged)

public:
    explicit VehicleData(QObject *parent = nullptr);

    int speed() const { return m_speed; }
    qreal odometer() const { return m_odometer; }
    int leftPower() const { return m_leftPower; }
    int rightPower() const { return m_rightPower; }
    bool turnLeft() const { return m_turnLeft; }
    bool turnRight() const { return m_turnRight; }
    bool highBeam() const { return m_highBeam; }
    bool headLamp() const { return m_headLamp; }
    bool fogLamp() const { return m_fogLamp; }
    bool doorOpen() const { return m_doorOpen; }
    bool parking() const { return m_parking; }
    bool safetyBelt() const { return m_safetyBelt; }
    bool absBrake() const { return m_absBrake; }
    bool emergencyLamp() const { return m_emergencyLamp; }
    bool engine() const { return m_engine; }
    bool engineOil() const { return m_engineOil; }

public slots:
    // MockDataSource (主线程) 调用
    void setSpeed(int v);
    void setLeftPower(int v);
    void setRightPower(int v);
    void setTurnLeft(bool v);
    void setTurnRight(bool v);
    void setHighBeam(bool v);
    void setHeadLamp(bool v);
    void setFogLamp(bool v);
    void setDoorOpen(bool v);
    void setParking(bool v);
    void setSafetyBelt(bool v);
    void setAbsBrake(bool v);
    void setEmergencyLamp(bool v);
    void setEngine(bool v);
    void setEngineOil(bool v);

    // OdoStore 启动时恢复历史里程
    void setOdometer(qreal v);

signals:
    void speedChanged();
    void odometerChanged();
    void leftPowerChanged();
    void rightPowerChanged();
    void turnLeftChanged();
    void turnRightChanged();
    void highBeamChanged();
    void headLampChanged();
    void fogLampChanged();
    void doorOpenChanged();
    void parkingChanged();
    void safetyBeltChanged();
    void absBrakeChanged();
    void emergencyLampChanged();
    void engineChanged();
    void engineOilChanged();

private:
    void onOdoTimer();

    int m_speed = 0;
    qreal m_odometer = 0;
    int m_leftPower = 0;
    int m_rightPower = 0;
    bool m_turnLeft = false;
    bool m_turnRight = false;
    bool m_highBeam = false;
    bool m_headLamp = false;
    bool m_fogLamp = false;
    bool m_doorOpen = false;
    bool m_parking = false;
    bool m_safetyBelt = false;
    bool m_absBrake = false;
    bool m_emergencyLamp = false;
    bool m_engine = false;
    bool m_engineOil = false;

    QTimer m_odoTimer;
};
