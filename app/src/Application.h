#pragma once

#include <QObject>

class VehicleData;
class MockDataSource;
class GpioManager;
class OdoStore;
class BuzzerController;

// Application - 聚合 C++ 后端对象, 由 MockDataSource 驱动 VehicleData。
//
// VehicleData 是 QML_SINGLETON, 由 QQmlEngine 创建; main.cpp 用
// engine.singletonInstance<VehicleData*>() 取得后传给 Application。
// MockDataSource 是主线程 QTimer, 构造即启动; 析构随 ~QObject 自动停止。

class Application : public QObject {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Application)

public:
    explicit Application(VehicleData *vehicle, QObject *parent = nullptr);
    ~Application() override;

    GpioManager *gpioManager() const { return m_gpio; }
    OdoStore *odoStore() const { return m_odo; }
    MockDataSource *mockDataSource() const { return m_mock; }   // 新增: 暴露给 QML

private:
    MockDataSource *m_mock = nullptr;
    GpioManager *m_gpio = nullptr;
    OdoStore *m_odo = nullptr;
    BuzzerController *m_buzzer = nullptr;
};
