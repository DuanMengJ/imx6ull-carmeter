#pragma once

#include <QObject>
#include <QTimer>
#include <QString>

class VehicleData;

// OdoStore - odometer 持久化 (周期写 + 关机写, 见 grilling 共识需求 4)。
//
// 启动时 load 历史里程 -> VehicleData::setOdometer; 周期 10s 写当前里程;
// 关机时 (QCoreApplication::aboutToQuit -> flush) 写最终值。
// 写用 QSaveFile (临时文件 + rename, 原子, 防断电损坏)。

class OdoStore : public QObject {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(OdoStore)

public:
    explicit OdoStore(VehicleData *vehicle,
                      const QString &path = QStringLiteral("/var/lib/carmeter/odo"),
                      QObject *parent = nullptr);
    ~OdoStore() override;

    void flush(); // 关机时调用 (aboutToQuit)

private:
    void load();
    void onTimeout();

    VehicleData *m_vehicle;
    QTimer m_timer;
    QString m_path;
};
