// CarMeter Qt 6 应用主程序
//
// 在 i.MX6ULL + LinuxFB 800x480 上跑 QML 仪表盘
//
// 启动流程:
//   1. QGuiApplication (无 QtWidgets, 纯 QML)
//   2. 设置 Qt 环境变量 (linuxfb, 字体路径, 资源)
//   3. QQmlApplicationEngine 加载 qrc:/qt/qml/CarMeter/qml/Main.qml
//   4. 进入事件循环

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QLoggingCategory>
#include <QtGlobal>

#include <cstdlib>
#include <clocale>

#include "Application.h"
#include "core/HudMonitor.h"
#include "core/MockDataSource.h"
#include "core/VehicleData.h"
#include "persist/OdoStore.h"

int main(int argc, char *argv[])
{
    // 板端 i.MX6ULL + LinuxFB 800x480: 强制 LinuxFB + 软件渲染 + wqy-zenhei 中文字体
    // x86 桌面默认让 Qt 走 hardware backend (EGL/OpenGL)
    // WSL2+WSLg 下 Mesa 默认用 llvmpipe 渲染的 buffer 不能被 D3D12 正确 swizzle/present (黑屏)
    // 解决: 强制 Mesa 用 d3d12 driver (WSLg GPU 透传通道) 或 swrast (X11/VirtualGL fallback)
    // 物理 Linux 桌面有 GPU: 不需要这个 override, 让 Mesa 自动选最优 driver
    // (CMake option BUILD_FOR_EMBEDDED 控制, 板端 carmeter.mk 通过 -DBUILD_FOR_EMBEDDED=ON 开启)
#ifdef BUILD_FOR_EMBEDDED
    qputenv("QT_QPA_PLATFORM", "linuxfb");
    qputenv("QT_QUICK_BACKEND", "software");
    qputenv("QT_QPA_FONTDIR", "/usr/share/fonts/wqy-zenhei");  // Qt6 不支持冒号分隔多路径 (fontDir 返回整个字符串)
#else
    // Mesa 26 默认优先选 d3d12 driver (WSLg D3D12 透传), 没有 GPU 透传时 fallback 到 swrast
    qputenv("MESA_LOADER_DRIVER_OVERRIDE", "d3d12");
#endif

    // 强制 UTF-8 locale：glibc 2.34+ 内建 C.UTF-8（不需 en_US.UTF-8 locale archive）
    // 板端 rootfs 没装 en_US.UTF-8 locale，但 Qt 6 强制 UTF-8 否则 abort
    if (!qEnvironmentVariableIsSet("LC_ALL")) {
        qputenv("LC_ALL", "C.UTF-8");
    }
    if (!qEnvironmentVariableIsSet("LANG")) {
        qputenv("LANG", "C.UTF-8");
    }

    // 强制 setlocale 读环境变量 (S99 设 LC_ALL=C.UTF-8), 让 Qt nl_langinfo
    // 检测时 locale 已是 C.UTF-8, 避免 "Detected locale C" 非 UTF-8 警告
    setlocale(LC_ALL, "");

    // QML 缓存 (减少启动时编译延迟)
    qputenv("QML_DISABLE_DISK_CACHE", "true");

    // 详细 Qt 调试日志（stdout 写入 init.d 串口 log）
    qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &ctx, const QString &msg) {
        const char *typeName = "DEBUG";
        switch (type) {
        case QtInfoMsg:     typeName = "INFO";  break;
        case QtWarningMsg:  typeName = "WARN";  break;
        case QtCriticalMsg: typeName = "CRIT";  break;
        case QtFatalMsg:    typeName = "FATAL"; break;
        case QtDebugMsg:    /* keep default "DEBUG" */ break;
        }
        fprintf(stderr, "[Qt-%s] %s\n", typeName, msg.toLocal8Bit().constData());
        fflush(stderr);
        // 自定义 handler 不再自动 abort, 必须显式恢复 Qt 默认 fatal 语义
        if (type == QtFatalMsg) std::abort();
    });

    QGuiApplication app(argc, argv);

    // 设置应用元信息
    QGuiApplication::setApplicationName("CarMeter");
    QGuiApplication::setApplicationVersion("0.1.0");
    QGuiApplication::setOrganizationName("CarMeter");
    QGuiApplication::setOrganizationDomain("carmeter.local");

    // Quick Controls 2 主题 (Basic 主题对嵌入式最简单)
    QQuickStyle::setStyle("Basic");

    // 静默 QtQuick 的非关键警告 (生产环境友好)
    QLoggingCategory::setFilterRules("qt.qml.diskcache.warning=false");

    QQmlApplicationEngine engine;

    // 把"是否板端"传给 QML, 让 Window 在板端启用 FramelessWindowHint (全屏无边框),
    // 在桌面/Qt Creator 下保留标题栏 (WSLg/桌面 WM 渲染 FramelessWindowHint 经常异常)
    engine.rootContext()->setContextProperty("embeddedMode",
#ifdef BUILD_FOR_EMBEDDED
        true
#else
        false
#endif
    );

    // HUD 调试层 (FPS + 进程 CPU): CARMETER_HUD 非空即开, 默认关闭。
    // hudEnabled/hudMonitor 必须先于 loadFromModule 注入 —— Dashboard.qml 在加载期间
    // 即实例化 HudOverlay 并求值 hudMonitor.fps 绑定, 上下文属性无变更通知,
    // 加载后才设置会得到永久的 ReferenceError (这是本设计的关键时序约束)。
    HudMonitor *hud = nullptr;
    if (qEnvironmentVariableIsSet("CARMETER_HUD"))
        hud = new HudMonitor(&engine);
    engine.rootContext()->setContextProperty("hudEnabled", hud != nullptr);
    engine.rootContext()->setContextProperty("hudMonitor", hud);

    // 加载主 QML
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("CarMeter", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    // QQuickWindow 只有 QML 加载完成后才存在; afterFrameEnd 在 basic loop (板端)
    // 下每渲染帧于 GUI 线程触发, 桌面 threaded loop 下自动转 queued 连接。
    if (hud)
        hud->setWindow(qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst()));

    // 拿 VehicleData QML singleton (QML_SINGLETON 由 engine 创建)
    auto *vehicle = engine.singletonInstance<VehicleData *>("CarMeter", "VehicleData");
    if (!vehicle) {
        qWarning("main: VehicleData singleton not found");
        return -1;
    }

    // 聚合后端: MockDataSource + GpioManager + OdoStore, 由 Application 装配
    Application application(vehicle);

    // 把 mock 控制句柄暴露给 QML, Dashboard.qml 在 bootAnimActive=false 时调 start()
    engine.rootContext()->setContextProperty("mock", application.mockDataSource());

    // 关机 flush odometer (周期写之外的双保险, grilling 需求 4)
    QObject::connect(&app, &QCoreApplication::aboutToQuit,
                     application.odoStore(), &OdoStore::flush);

    return app.exec();
}
