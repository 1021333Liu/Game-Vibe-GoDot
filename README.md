# Game Vibe Godot Prototype

Godot 4.x 重建原型，用来验证 Game Vibe 是否值得从 Kaboom/Vite 课程项目迁移到商业化 2D 工作流。

## 目标

- 先做一个可玩的垂直切片，而不是全量迁移。
- 保留西游 + The Binding of Isaac 式房间制射击方向。
- 优先验证手感、碰撞、房间节奏、敌人反馈、道具差异和 UI 质感。

## 当前内容

- 1920x1080 项目设置。
- 一个主场景 `scenes/main.tscn`。
- 一个可移动的玩家原型 `scripts/player.gd`。
- WASD 移动，方向键射击输入已在 `project.godot` 中登记。

## 打开方式

1. 安装 Godot 4.x。
2. 打开 Godot Project Manager。
3. Import 这个文件夹：`D:\Desktop\DeskHub\Game Vibe Godot`。
4. 打开项目后运行主场景。

## 迁移原则

- 当前 Kaboom 版本保留为设计草稿和历史记录。
- Godot 版本不照搬所有功能，先重做一个高质量房间。
- 所有新增内容都要服务于“更好玩、更清楚、更稳定”，而不是堆机制数量。
