#include "GpioManager.h"

#include <cerrno>
#include <cstring>

#include <QLoggingCategory>

#ifdef BUILD_FOR_EMBEDDED
#include <gpiod.h>
#endif

GpioManager::GpioManager(QObject *parent)
    : QObject(parent)
{
#ifdef BUILD_FOR_EMBEDDED
    // buzzer 在 GPIO1_IO19 = gpiochip0 line19 (见 ADR-0002)
    m_chip = gpiod_chip_open_by_name("gpiochip0");
    if (!m_chip) {
        qWarning("GpioManager: cannot open gpiochip0: %s", std::strerror(errno));
        return;
    }
    m_buzzerLine = gpiod_chip_get_line(m_chip, 19);
    if (!m_buzzerLine) {
        qWarning("GpioManager: cannot get line 19: %s", std::strerror(errno));
        gpiod_chip_close(m_chip);
        m_chip = nullptr;
        return;
    }
    if (gpiod_line_request_output(m_buzzerLine, "carmeter-buzzer", 0) < 0) {
        qWarning("GpioManager: cannot request line 19 as output: %s", std::strerror(errno));
        m_buzzerLine = nullptr;
        gpiod_chip_close(m_chip);
        m_chip = nullptr;
        return;
    }
    qInfo("GpioManager: buzzer line 19 acquired on gpiochip0");
#else
    qInfo("GpioManager: stub mode (non-embedded), buzzer no-op");
#endif
}

GpioManager::~GpioManager()
{
#ifdef BUILD_FOR_EMBEDDED
    if (m_buzzerLine)
        gpiod_line_release(m_buzzerLine);
    if (m_chip)
        gpiod_chip_close(m_chip);
#endif
}

void GpioManager::setBuzzer(bool on)
{
    if (m_buzzer == on)
        return;
    m_buzzer = on;
#ifdef BUILD_FOR_EMBEDDED
    if (m_buzzerLine)
        gpiod_line_set_value(m_buzzerLine, on ? 1 : 0);
#else
    qInfo("GpioManager: setBuzzer(%d) [stub]", static_cast<int>(on));
#endif
    emit buzzerChanged();
}
