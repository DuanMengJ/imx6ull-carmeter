#include "OdoStore.h"
#include "VehicleData.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QTextStream>
#include <QLoggingCategory>

OdoStore::OdoStore(VehicleData *vehicle, const QString &path, QObject *parent)
    : QObject(parent)
    , m_vehicle(vehicle)
    , m_path(path)
{
    if (!m_vehicle) {
        qWarning("OdoStore: null VehicleData, persistence disabled");
        return;
    }

    load();

    // 周期 10s 写 (grilling: 周期写 + 关机写, 断电最多丢最近 10s)
    m_timer.setInterval(10000);
    connect(&m_timer, &QTimer::timeout, this, &OdoStore::onTimeout);
    m_timer.start();
}

OdoStore::~OdoStore()
{
    flush(); // 析构时双保险 (正常流程 aboutToQuit 已 flush)
}

void OdoStore::load()
{
    if (!m_vehicle)
        return;

    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return; // 文件不存在 (首次启动), odometer 保持初始值

    qreal v = 0;
    QTextStream in(&f);
    in >> v;
    if (in.status() == QTextStream::Ok)
        m_vehicle->setOdometer(v);
}

void OdoStore::flush()
{
    if (!m_vehicle)
        return;

    QDir().mkpath(QFileInfo(m_path).absolutePath());

    QSaveFile f(m_path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning("OdoStore: cannot open %s for write", qPrintable(m_path));
        return;
    }
    QTextStream out(&f);
    out << m_vehicle->odometer();
    out.flush();
    if (!f.commit())
        qWarning("OdoStore: commit failed for %s", qPrintable(m_path));
}

void OdoStore::onTimeout()
{
    flush();
}
