#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

class QQuickWindow;

// HudMonitor - 屏幕 HUD 调试层数据源 (渲染 FPS + 本进程 CPU 占用), 仅开发调试用。
//
// 开关: 环境变量 CARMETER_HUD 非空即开, 默认关闭。
//       main.cpp 读取 (qEnvironmentVariableIsSet) 并决定是否创建本对象,
//       与 embeddedMode 先例 (main.cpp:94-100) 一致。
// 生命周期: main.cpp 持有, parent = &engine; setWindow() 必须在
//       engine.loadFromModule() 之后调用 —— QQuickWindow 只有 QML 加载完成后才存在。
// 数据通路:
//   FPS: QQuickWindow::afterFrameEnd() 每渲染帧触发一次 -> ++m_frames;
//        QTimer tick 时按 QElapsedTimer 实际窗口换算 (而非固定 500ms, 避免
//        timer 抖动高估), 一阶指数平滑 α=0.5。
//        (basic 渲染循环下该信号在 GUI 线程每帧可靠触发, frameSwapped 不保证)
//   CPU: Δ(utime+stime) / Δ(/proc/stat 首行 cpu 总 jiffies) * 100, 下限 0。
//        单核板端比值即进程 CPU%; 多核桌面下为进程跨核累计利用率, 可 >100
//        (调试工具显示原始值, 不 clamp 上限)。
//        /proc/self/stat 字段 14=utime, 15=stime (1-based); comm 可能含空格,
//        必须用最后一个 ')' 之后的部分再拆分 (见 cpp 注释)。首个采样点跳过。
class HudMonitor : public QObject {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(HudMonitor)

public:
    explicit HudMonitor(QObject *parent = nullptr);

    // loadFromModule 之后调用。window 为 null 时 no-op + qWarning。
    // 仅当 CARMETER_HUD 非空时连接信号并启动定时器 (main.cpp 已保证, 双重保险)。
    void setWindow(QQuickWindow *window);

    Q_PROPERTY(int fps READ fps NOTIFY fpsChanged)
    Q_PROPERTY(int cpuPercent READ cpuPercent NOTIFY cpuPercentChanged)
    int fps() const { return m_fps; }
    int cpuPercent() const { return m_cpuPercent; }

signals:
    void fpsChanged();
    void cpuPercentChanged();

private slots:
    void onFrameEnd();   // afterFrameEnd: 仅 m_frames++
    void onTick();       // QTimer 500ms: 算 FPS/CPU, emit, 重置帧计数

private:
    struct CpuSample { qint64 utimeStime = 0; qint64 totalJiffies = 0; };
    bool readProcStats(CpuSample &out) const;   // /proc/self/stat + /proc/stat

    QQuickWindow *m_window = nullptr;
    QTimer m_timer;                       // 500ms, 构造不启动
    QElapsedTimer m_elapsed;              // FPS 实际窗口计时 (timer 抖动时避免高估)
    int m_frames = 0;                     // 仅 GUI 线程访问 (两种 loop 下信号槽都落在 GUI 线程)
    double m_fpsSmoothed = -1.0;          // -1 = 首个窗口直接取 raw
    int m_fps = 0;
    int m_cpuPercent = 0;
    CpuSample m_baseline;
    bool m_haveBaseline = false;          // 首个采样点跳过
    bool m_procFailWarned = false;        // /proc 读取失败仅告警一次, 避免每 500ms 刷屏
};
