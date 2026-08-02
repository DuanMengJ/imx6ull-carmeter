# 仪表 PNG 资

> **来源**: 从 `ebf_linux_qt_demo/Skin/images/car/` 复制（原项目所有者原创）。
> **修改**: 顶层 3 张重命名以符合项目命名约定（`ic_background` → `background` 等），`left/*.png` 和 `right/*.png` 原文件名已匹配无需重命名。

## 文件清单

### 顶层（25 张）

- `background.png` — 仪表主背景
- `point_hand.png` — 速度指针
- `menu_pressed.png` — Home 按钮按下态
- `left_value_0.png` ... `left_value_10.png` — 温度条 11 段（0=空，10=满）
- `right_value_0.png` ... `right_value_10.png` — 油量条 11 段（0=空，10=满）

### mark/（24 张）

指示灯图标，每个 PNG 包含 on/off 两态（具体文件名区分）：

- abs, car, door_open, emergency_lamp, engine, enginoil, fog_lamp, headlamp
- highbeam, parking, safety_belt, turn_left, turn_right
- (每种一般 1-2 张，文件名后缀 _off / _on / 单纯名称)

## 引用方式（QML）

```qml
Image {
    source: "qrc:/qt/qml/CarMeter/images/car/background.png"
}
```

或在 CMake 资源声明（`qt_add_resources`）里注册整个目录。

## 版权

本目录下的 PNG 由项目所有者原创，与野火原 `ebf_linux_qt_demo` 项目**无版权关联**（仅作 UI 设计参考迁移，原始 PNG 已在 M2 复制到本仓库）。

## 部署

- **build 时**：通过 `qt_add_resources` 打包进 Qt 资源（编译进二进制，无文件系统依赖）
- **运行时**：从 `/usr/share/CarMeter/images/car/` 解包（如果不用资源系统）

## M2 完成度

- [x] 25 张顶层 PNG 复制
- [x] 24 张 mark PNG 复制
- [x] README.md 写完
- [ ] CMake 资源声明（`CMakeLists.txt` 顶层 `qt_add_resources`）— 待 M3