cmake_minimum_required(VERSION 3.21)
project(carmeter VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Qt 6 必需
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.5)

# ----------------------------------------------------------------------
# 可执行文件
# ----------------------------------------------------------------------
qt_add_executable(carmeter
    src/main.cpp
    src/Application.h
    src/Application.cpp
    src/core/VehicleData.h
    src/core/VehicleData.cpp
    src/core/BuzzerController.h
    src/core/BuzzerController.cpp
    src/core/MockDataSource.h
    src/core/MockDataSource.cpp
    src/io/GpioManager.h
    src/io/GpioManager.cpp
    src/persist/OdoStore.h
    src/persist/OdoStore.cpp
)

# 平台开关: BUILD_FOR_EMBEDDED=ON 时启用板端硬编码 (linuxfb + software + wqy-zenhei)
# 默认 OFF → x86 桌面 Qt Creator 直接 Run, Qt 自动选平台/GPU/系统字体
# 板端 buildroot 在 package/carmeter/carmeter.mk 通过 -DBUILD_FOR_EMBEDDED=ON 打开
option(BUILD_FOR_EMBEDDED "Build for embedded i.MX6ULL (linuxfb + software + wqy-zenhei)" OFF)

if(BUILD_FOR_EMBEDDED)
    target_compile_definitions(carmeter PRIVATE BUILD_FOR_EMBEDDED=1)
endif()

# libgpiod (板端 buzzer 控制, 见 ADR-0002; PC 端 BUILD_FOR_EMBEDDED=OFF 时 stub 模式不 link)
if(BUILD_FOR_EMBEDDED)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GPIOD REQUIRED IMPORTED_TARGET libgpiod)
    target_link_libraries(carmeter PRIVATE PkgConfig::GPIOD)
endif()

target_link_libraries(carmeter PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

# ----------------------------------------------------------------------
# QML 模块 (qmldir 自动生成)
# ----------------------------------------------------------------------
qt_add_qml_module(carmeter
    URI CarMeter
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Dashboard.qml
        qml/SpeedIndicator.qml
        qml/WarningLights.qml
        qml/ValueBars.qml
    RESOURCES
        # PNG 资源打包到 Qt 资源系统 (编译进二进制)
        resources/images/car/background.png
        resources/images/car/point_hand.png
        resources/images/car/left_value_0.png
        resources/images/car/left_value_1.png
        resources/images/car/left_value_2.png
        resources/images/car/left_value_3.png
        resources/images/car/left_value_4.png
        resources/images/car/left_value_5.png
        resources/images/car/left_value_6.png
        resources/images/car/left_value_7.png
        resources/images/car/left_value_8.png
        resources/images/car/left_value_9.png
        resources/images/car/left_value_10.png
        resources/images/car/right_value_0.png
        resources/images/car/right_value_1.png
        resources/images/car/right_value_2.png
        resources/images/car/right_value_3.png
        resources/images/car/right_value_4.png
        resources/images/car/right_value_5.png
        resources/images/car/right_value_6.png
        resources/images/car/right_value_7.png
        resources/images/car/right_value_8.png
        resources/images/car/right_value_9.png
        resources/images/car/right_value_10.png
        resources/images/car/mark/abs_on.png
        resources/images/car/mark/car.png
        resources/images/car/mark/door_open.png
        resources/images/car/mark/emergency_lamp_on.png
        resources/images/car/mark/engine_error.png
        resources/images/car/mark/engine_on.png
        resources/images/car/mark/enginoil_on.png
        resources/images/car/mark/fog_lamp_on.png
        resources/images/car/mark/headlamp_on.png
        resources/images/car/mark/highbeam.png
        resources/images/car/mark/parking_on.png
        resources/images/car/mark/safety_belt_on.png
        resources/images/car/mark/turn_left_on.png
        resources/images/car/mark/turn_right_on.png
)

# ----------------------------------------------------------------------
# 安装规则 (buildroot 会调用 install strip 阶段)
# ----------------------------------------------------------------------
install(TARGETS carmeter
    RUNTIME DESTINATION bin
)

# 让 QML 类型注册生成的 <VehicleData.h> 等 __has_include 能找到 (header 在 src/core 等子目录)
target_include_directories(carmeter PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core
    ${CMAKE_CURRENT_SOURCE_DIR}/src/io
    ${CMAKE_CURRENT_SOURCE_DIR}/src/persist
)