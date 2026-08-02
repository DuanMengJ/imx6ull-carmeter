#include "Application.h"

#include "core/BuzzerController.h"
#include "core/MockDataSource.h"
#include "core/VehicleData.h"
#include "io/GpioManager.h"
#include "persist/OdoStore.h"

Application::Application(VehicleData *vehicle, QObject *parent)
    : QObject(parent)
{
    Q_ASSERT(vehicle);

    m_mock = new MockDataSource(vehicle, this);
    m_gpio = new GpioManager(this);
    m_odo = new OdoStore(vehicle, QStringLiteral("/var/lib/carmeter/odo"), this);
    m_buzzer = new BuzzerController(vehicle, m_gpio, this);
}

Application::~Application()
{
    // MockDataSource/OdoStore 均为 this 子对象: ~QObject 自动删除。
    // MockDataSource 是主线程 QTimer, 无需显式停止; OdoStore 析构 flush。
}
