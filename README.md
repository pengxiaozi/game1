# 九州英灵录

Godot 4.7.2 单机试玩版：2D 国风英灵塔防。

## 运行

使用安装在 `H:\godot` 的 Godot 4.7.2：

```powershell
& 'H:\godot\Godot_v4.7.2-stable_win64.exe' --editor --path 'H:\games'
```

也可以直接运行游戏：

```powershell
& 'H:\godot\Godot_v4.7.2-stable_win64.exe' --path 'H:\games'
```

## 操作

- 主菜单点击“入阵守关”或按 Enter。
- 点击场上英灵：查看详情并选中。
- 点击道路两侧的发光格：移动或部署选中的英灵。
- 点击底部候补英灵：消耗 6 灵石招募。
- 点击 `刷新`：消耗 4 灵石重置商店。
- 点击 `开战` 或按 `Space`：开始下一波。
- 战斗中按 `Space`：暂停 / 继续。
- 按 `1` / `2`：切换 1 倍 / 2 倍速。
- `Esc`：暂停 / 继续。
- 选中英灵后点击右侧 `撤回候补`：撤下场。
- 相同英灵 3 个会自动合成升星。

## 玩法内容

- 12 名历史与神话混搭英灵。
- 8 个由数据驱动的羁绊。
- 20 波敌人，第 20 波包含饕餮残影 Boss。
- 灵石、军令、战功三种局内资源。
- 远程、近战、范围、控制、治疗、机关等不同战斗定位。
- 纯本地运行，不需要联网服务。

## 数据与扩展

英雄、敌人和羁绊分别位于：

- `data/heroes.json`
- `data/enemies.json`
- `data/synergies.json`

核心战斗绘制在 `scripts/main.gd` 中，数据解析、棋盘、羁绊计算和设置存档分别由独立脚本负责。

## 测试

```powershell
& 'H:\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'H:\games' --script 'res://tests/smoke_test.gd'
```
