# Godot XR Tools 手部原始资源

作者：DigitalN8m4r3 / Miodrag Sejic。许可：CC0 1.0，完整文本见 License.md，源模型说明见 About.md。

固定上游版本：`2d8db860d1adbee97c0968c4b07afe9348263926`。
来源：https://github.com/GodotVR/godot-xr-tools/tree/2d8db860d1adbee97c0968c4b07afe9348263926/addons/godot-xr-tools/hands

`manifest.json` 记录运行所用原始文件和 SHA-256。另保留作者的右手 Blender 源文件及原场景/材质定义用于追溯。下载文件不在构建时联网更新。

本项目使用高精度 Hand_Glove_L/R 与深色露指手套材质。仅引入模型、贴图和五种骨骼姿势，不安装 XR 插件。运行时保留作者的 glTF 原始关节坐标，使手势不受 Blender 重定向影响；`tools/import_hands.py` 生成可编辑的双手 Blender 文件和本项目原创袖子模型。
