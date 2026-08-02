#pragma once

#include <QObject>
#include <QTimer>

class VehicleData;

// MockDataSource - 开发期仪表数据模拟源 (见 ADR-0004)。
//
// CAN 通信已从本项目移除 (ADR-0001 superseded by ADR-0004)。本类在主线程用
// 50ms QTimer 复刻原 can-sim.py 的 demo 语义, 直接调 VehicleData 的 setter:
//
//   启动由 QML 在 Dashboard.bootAnimActive=false 时显式调用 start():
//     Idle     -> 构造后不启动 timer，等 QML 信号
//     RampUp   -> 2s: power 0→11, speed 0→180; 转向双闪 + 安全带灯亮 4s
//     Oscillate -> 永久: speed 180→0→180 (4s 周期), power 锁死 11
//
//   副作用: safetyBelt=true + speed 振荡 -> BuzzerController 在 Oscillate 阶段
//          按 off/间歇/持续 三态切换; 桌面 stub 仅日志, 板端会响.
class MockDataSource : public QObject {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(MockDataSource)

public:
    explicit MockDataSource(VehicleData *vehicle, QObject *parent = nullptr);

public slots:
    // 幂等启动. 由 QML 在 Dashboard.bootAnimActive=false 时调用.
    // 调用前 mock 不向 VehicleData 写任何数据 (避免启动跳变).
    void start();

private slots:
    void onTick();
    void onSafetyBeltOff();           // 安全带灯 4s 后熄灭

private:
    enum class Phase { Idle, RampUp, Oscillate };
    VehicleData *m_vehicle;
    QTimer m_timer;
    QTimer m_safetyBeltTimer;        // 安全带灯 4s 延时关闭
    Phase m_phase = Phase::Idle;
    qint64 m_phaseStartMs = 0;        // monotonic ms
    bool m_started = false;           // start() 幂等保护

    void applyTelltales();            // 转向双闪 + 安全带灯亮 4s
    void onTickRampUp(qint64 elapsedMs);
    void onTickOscillate(qint64 elapsedMs);
};
