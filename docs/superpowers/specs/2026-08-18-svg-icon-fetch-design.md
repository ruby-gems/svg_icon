# svg_icon fetch CLI — 设计文档

- 日期:2026-08-18
- 状态:已批准

## 背景

gem 内置的 icon set json(bi/bx/lucide/heroicons)来自 [iconify/icon-sets](https://github.com/iconify/icon-sets/tree/master/json)。把所有 icon set 打包进 gem 不现实。需要一个 CLI 命令,让用户从 iconify/icon-sets 抓取任意 icon set 到项目本地,并通过配置使用。

## 目标

- `svg_icon fetch <name>` 从 iconify/icon-sets 下载 `<name>.json` 到项目 `config/svg_icons/` 目录
- 下载的 json 作为独立 icon set 使用:`config.icon = "<name>"` 时优先加载它,与内置 lucide 等平级
- 零新增运行时依赖(标准库 `net/http` + 现有 `multi_json`)
- 下载后离线可用,建议提交进版本控制

## 架构

### 1. CLI(`exe/svg_icon`)

```
$ svg_icon fetch bi
Fetching https://raw.githubusercontent.com/iconify/icon-sets/master/json/bi.json
Saved to config/svg_icons/bi.json
```

- 使用 `OptionParser` 做子命令分发
- `fetch <name>` 行为:
  - 下载 URL:`https://raw.githubusercontent.com/iconify/icon-sets/master/json/<name>.json`
  - 目标:`<icons_path>/<name>.json`,目录不存在时自动创建
  - 先写临时文件,校验成功后 rename 到目标;失败不留下半截文件
  - 目标已存在则覆盖(作为更新手段)
  - 校验规则:JSON 可解析,且是 Hash 且含 `icons`(Hash)键
- 错误处理(全部 stderr + exit 1):
  - 网络错误 / HTTP 非 200 → `FetchError`
  - JSON 无效或不含 `icons` → `FetchError`
  - 缺少子命令或参数 → usage 提示,exit 1

### 2. 配置扩展(`lib/svg_icon/configuration.rb`)

- 新增 `attr_accessor :icons_path`,默认 `File.join(Dir.pwd, "config/svg_icons")`
- 语义:外部 icon set 的查找目录

### 3. 数据查找(`lib/svg_icon.rb`)

`file_data` 查找顺序:

1. 外部 `<icons_path>/<icon>.json`(存在则优先)
2. 内置 `lib/data/<icon>.json`
3. 都不存在 → 现有 `SvgIcon::Error`("Icon data file not found")

外部优先:用户下载的版本覆盖内置,且内置 bi/bx 等与下载同名时以外部为准(数据更新)。

### 4. Fetcher(`lib/svg_icon/fetcher.rb`)

```ruby
module SvgIcon
  class FetchError < Error; end

  class Fetcher
    def initialize(base_url: DEFAULT_BASE_URL, http: Net::HTTP, ...)
    def fetch(name, destination) # destination 是完整目标文件路径(含文件名),由调用方组装
    # 返回 bool/抛出 FetchError
  end
end
```

- `base_url` 和 http 客户端可注入,便于测试
- 下载 → 解析校验 → 写临时文件 → rename

## 错误处理汇总

| 场景 | 行为 |
| --- | --- |
| 网络错误 / DNS 失败 | `SvgIcon::FetchError`,exit 1 |
| HTTP 404(icon set 不存在) | `SvgIcon::FetchError`,exit 1 |
| 返回体不是合法 JSON | `SvgIcon::FetchError`,exit 1 |
| JSON 不含 `icons` 对象 | `SvgIcon::FetchError`,exit 1 |
| `icons_path` 目录不可写 | 原样异常,exit 1 |

## 测试(minitest)

- **fetcher_test.rb**(`test/fetcher_test.rb`)
  - 成功下载并写入正确文件(mock HTTP)
  - 404 → FetchError
  - 无效 JSON → FetchError
  - 缺 `icons` 键 → FetchError
  - 失败时不留下临时/半截文件
- **查找顺序**(`test/svg_icon_test.rb` 扩展)
  - `icons_path` 存在同名文件 → 加载外部
  - 外部没有 → 回退内置
  - 都没有 → `SvgIcon::Error`
- **CLI 集成**(`test/cli_test.rb`)
  - 在临时目录跑 `svg_icon fetch <name>`,断言 exit 0、文件写入
  - 无效参数 → exit 1

## README 更新

- 新增 "Fetching icon sets" 章节:安装、`svg_icon fetch bi` 用法、`config.icon` / `config.icons_path` 示例
- 建议把 `config/svg_icons/` 提交进版本控制,部署无需重新抓取
