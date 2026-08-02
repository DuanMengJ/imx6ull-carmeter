#pragma once

#include <QObject>

// GpioManager - libgpiod 封装, 控制 buzzer 等 GPIO (见 ADR-0002)。
//
// buzzer: GPIO1_IO19 = gpiochip0 line19, 高电平有效 (野火教材 + ADR-0002)。
// 板端用 libgpiod 1.x (buildroot 1.2.1); PC 端 stub 模式 (BUILD_FOR_EMBEDDED off)。

#ifdef BUILD_FOR_EMBEDDED
struct gpiod_chip;  // 前向声明, 不暴露 <gpiod.h> 到头文件
struct gpiod_line;
#endif

class GpioManager : public QObject {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(GpioManager)

public:
    explicit GpioManager(QObject *parent = nullptr);
    ~GpioManager() override;

    bool buzzer() const { return m_buzzer; }

public slots:
    void setBuzzer(bool on);

signals:
    void buzzerChanged();

private:
    bool m_buzzer = false;

#ifdef BUILD_FOR_EMBEDDED
    gpiod_chip *m_chip = nullptr;
    gpiod_line *m_buzzerLine = nullptr;
#endif
};
