#include "HudMonitor.h"

#include <QFile>
#include <QQuickWindow>
#include <QtGlobal>

#include <algorithm>

HudMonitor::HudMonitor(QObject *parent)
    : QObject(parent)
{
    // 与 VehicleData::m_odoTimer (VehicleData.cpp:8-10) / MockDataSource 的
    // QTimer 成员先例一致; 不在这里 start —— 等 setWindow() (HUD 激活时)。
    m_timer.setInterval(500);
    connect(&m_timer, &QTimer::timeout, this, &HudMonitor::onTick);
}

void HudMonitor::setWindow(QQuickWindow *window)
{
    // 调试层自身失败必须可诊断: window 为 null (qobject_cast 失败/根对象非
    // QQuickWindow) 时告警; m_window 已设置 (幂等) 与 env 关闭 (main.cpp 已
    // 保证不创建本对象) 两个分支保持静默。
    if (!window) {
        qWarning("HudMonitor: window is null, HUD disabled");
        return;
    }
    if (m_window || !qEnvironmentVariableIsSet("CARMETER_HUD"))
        return;
    m_window = window;
    // basic loop (板端): 同线程 direct; threaded loop (桌面): 渲染线程 -> AutoConnection 自动 queued。
    // 两种都落到 GUI 线程执行, m_frames 无数据竞争。不要改用 DirectConnection。
    connect(window, &QQuickWindow::afterFrameEnd,
            this, &HudMonitor::onFrameEnd);
    m_elapsed.start();
    m_timer.start();
}

void HudMonitor::onFrameEnd()
{
    ++m_frames;
}

void HudMonitor::onTick()
{
    // ── FPS: 实际窗口内帧数 / 窗口时长 + 一阶指数平滑 (α≈0.5) ──
    // QTimer 只能延迟触发, 实际窗口 >= 500ms; 用 QElapsedTimer 换算避免
    // 固定窗口假设在加载/渲染停顿期间系统性高估 FPS (高估可达 20-100%)。
    const qint64 elapsedMs = m_elapsed.restart();
    const int rawFps = qRound(m_frames * 1000.0 / (std::max)(elapsedMs, qint64(1)));
    m_frames = 0;
    if (m_fpsSmoothed < 0.0)
        m_fpsSmoothed = rawFps;                       // 首窗直接取原始值
    else
        m_fpsSmoothed = m_fpsSmoothed * 0.5 + rawFps * 0.5;
    const int fps = qRound(m_fpsSmoothed);
    if (fps != m_fps) {
        m_fps = fps;
        emit fpsChanged();
    }

    // ── CPU: Δ(utime+stime) / Δ(总 jiffies); 首个采样点跳过 ──
    CpuSample now;
    if (!readProcStats(now)) {
        // /proc 持续不可读时 CPU 会恒 0, 与真实 0% 无法区分 —— 告警一次避免误导
        if (!m_procFailWarned) {
            m_procFailWarned = true;
            qWarning("HudMonitor: failed to read /proc stats, CPU display frozen");
        }
        return;
    }
    if (!m_haveBaseline) {
        m_baseline = now;
        m_haveBaseline = true;
        return;
    }
    const qint64 dProc = now.utimeStime - m_baseline.utimeStime;
    const qint64 dTotal = now.totalJiffies - m_baseline.totalJiffies;
    m_baseline = now;
    // 下限 0: 解析异常导致 dProc<0 时负值无物理意义 (显示层)
    const int cpu = (dTotal > 0) ? (std::max)(0, qRound(double(dProc) * 100.0 / double(dTotal))) : 0;
    if (cpu != m_cpuPercent) {
        m_cpuPercent = cpu;
        emit cpuPercentChanged();
    }
}

bool HudMonitor::readProcStats(CpuSample &out) const
{
    // /proc/self/stat: 字段(1-based) 14=utime, 15=stime。
    // comm 可含空格/括号, 整行按空白拆分会错位 —— 先取最后一个 ')'，
    // 之后的部分从字段 3 (state) 开始: tok[0]=state ... tok[11]=utime, tok[12]=stime。
    QFile procStat(QStringLiteral("/proc/self/stat"));
    if (!procStat.open(QIODevice::ReadOnly))
        return false;
    const QByteArray line = procStat.readLine();
    const int close = line.lastIndexOf(')');
    if (close < 0)
        return false;
    const QList<QByteArray> tok = line.mid(close + 1).simplified().split(' ');
    if (tok.size() <= 12)
        return false;
    const qint64 utime = tok.at(11).toLongLong();
    const qint64 stime = tok.at(12).toLongLong();

    // /proc/stat 首行: "cpu user nice system idle iowait irq softirq steal guest guest_nice"
    // 总 jiffies = 前 10 个数值之和 (含 idle; 单核板因此比值即进程 CPU%)
    QFile stat(QStringLiteral("/proc/stat"));
    if (!stat.open(QIODevice::ReadOnly))
        return false;
    const QByteArray firstLine = stat.readLine();
    if (!firstLine.startsWith("cpu "))
        return false;
    const QList<QByteArray> cpus = firstLine.simplified().split(' ');
    qint64 total = 0;
    for (int i = 1; i < cpus.size() && i <= 10; ++i)
        total += cpus.at(i).toLongLong();

    out.utimeStime = utime + stime;
    out.totalJiffies = total;
    return true;
}
