# 《烬峰回响》(Ashen Echo)

一款用 **Godot 4.4** 制作的 3D 开放世界动作冒险单机游戏,面向 iPhone / iPad(横屏)。
纯单机、完整剧情、全中文本地化。所有美术、音频资源均为原创、程序化生成,无任何第三方商业素材。

## 游戏概览

- **世界观**:霜烬大陆——被"寒烬"侵蚀的雪原古国。玩家扮演寻火人洛尘,追寻失踪的师尊老窑,揭开烬峰之火熄灭的真相。
- **主线**:8 章完整主线(序章 → 烬峰抉择),3 个结局 + 1 个隐藏结局「薪传」(集齐民谣碎片解锁)。
- **支线**:6 个支线任务 + 3 个隐藏任务。
- **场景**:环抱港小镇、双子灯塔、猎人小屋、地穴、雪原神龛、烬峰祭坛,约 512m×512m 无缝可探索地形。
- **系统**:昼夜交替、四种动态天气(晴/雪/雾/暴雪)、近战连招(轻击/重击)+ 翻滚 + 格挡、技能树(3 系)、背包装备、商店、NPC 日程行为、任务日志、4 存档位(自动+手动)、电影式过场动画。

## 环境要求

- Godot **4.4.1 或更高**(标准版即可,非 .NET 版)
- 桌面测试:Windows / macOS / Linux 均可
- iOS 导出:Mac + Xcode + Apple 开发者账号

## 快速开始

1. 用 Godot 打开本目录(`project.godot`),首次打开会自动导入资源。
2. 按 F5(或运行按钮)即可游玩。桌面测试时鼠标模拟触摸。
3. 触屏操作见游戏内"操作说明":左侧虚拟摇杆移动,右侧按钮攻击/翻滚/格挡/交互;右上角图标打开背包/技能/任务日志。

### 自测模式(可选)

命令行运行集成测试(36 项检查,涵盖任务链、战斗、存档、对话、UI、结局分支):

```bash
ASHEN_TEST=1 godot --headless --path .
```

输出 `TEST_RESULT: PASS` 即全部通过。

## 目录结构

```
res://
├── project.godot          # 工程配置(移动渲染器、横屏、触摸模拟)
├── export_presets.cfg      # iOS 导出预设
├── icon.svg
├── data/                   # JSON 数据驱动:任务/物品/NPC/对话/敌人/地点
├── scripts/
│   ├── autoload/           # 全局单例:EventBus, GameData, GameState,
│   │                       # QuestManager, DialogueManager, SaveManager,
│   │                       # AudioManager, TouchInput
│   ├── world/              # 地形生成、昼夜、天气、场景道具
│   ├── entities/           # 玩家、NPC、敌人、拾取物、程序化建模
│   └── ui/                 # HUD、虚拟按键、背包、技能树、商店、任务日志
├── scenes/main.tscn        # 唯一主场景,其余全部运行时程序化构建
├── assets/
│   ├── fonts/              # Noto Sans SC 子集(1182 字,含全部游戏文本)
│   ├── textures/           # 程序化生成的 PBR 纹理
│   ├── ui/                 # 标题画面、海报
│   └── audio/              # 6 首音乐 + 2 环境音 + 17 音效(全部原创生成)
├── tools/                  # 纹理/音频生成脚本(Python)
└── test/integration_test.gd
```

**架构说明**:世界、建筑、角色模型均在运行时由代码程序化生成(地形为分块高度图 + 顶点色),因此仓库体积小、加载快,同时保证资源 100% 原创。数值与剧情全部走 `data/*.json`,改数值不用改代码。

## iOS 导出步骤

1. **准备**:Mac 上安装 Xcode(含 iOS SDK),登录 Apple Developer 账号;Godot 中安装 **iOS 导出模板**(编辑器 → 管理导出模板)。
2. **签名**:在 `export_presets.cfg`(或导出对话框)中填写:
   - `application/app_store_team_id`:你的 Team ID(Developer Portal 可查)
   - Bundle Identifier 改为你自己的反向域名(默认 `com.ashenecho.game`)
   - Debug 证书选择 "Apple Development",Release 选择 "Apple Distribution",并配置对应的 Provisioning Profile
3. **导出**:编辑器 → 项目 → 导出 → 选择 "iOS" 预设 → "导出"。若选择导出为 Xcode 工程,用 Xcode 打开后直接 `Cmd+R` 真机运行;若直接导出 IPA,可通过 Xcode 的 Devices 窗口或 TestFlight 安装到设备。
4. **上架 App Store**:使用 App Store Connect 创建条目后用 Transporter 或 `xcrun altool` 上传 IPA。

> 付费 Apple Developer 账号($99/年)才能真机部署与上架;免费账号仅模拟器。

## 已知边界(诚实说明)

- 画面为程序化生成的风格化低多边形 + PBR 材质,非照片级 AAA 表现;在 iPhone 上以流畅性优先。
- 剧情文本、配音为中文文本呈现(无真人语音);音乐音效为程序化原创生成。
- 物理、AI、任务、存档、天气、昼夜等核心系统均为真实实现,非演示界面。

## 重新生成资源(可选)

```bash
python3 tools/gen_textures.py   # 重生成全部纹理与UI图
python3 tools/gen_audio.py      # 重生成全部音乐/音效
```
