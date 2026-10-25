"""Verify the final runtime evidence and publish the local revisit acceptance/gallery."""
from pathlib import Path
import datetime
import hashlib
import html
import json

ROOT = Path(__file__).resolve().parents[1]
PROOF = ROOT / 'docs/verification/revisits'
GAME = ROOT / 'game'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text('utf-8'))

def main():
    catalog = read(GAME / 'data/learning/revisits.json')
    targets = catalog['targets']
    assert len(targets) == 62 and len({r['id'] for r in targets}) == 62
    letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    assert {r['id'] for r in targets if r['group'] == 'letters'} == {
        f'letter/{letter}/{dimension}' for letter in letters for dimension in ['case','image']}
    p2 = read(GAME / 'data/learning/p2_journey.json')
    source_steps = {f'U1-{n:02}' for n in range(1,11)}
    source_steps.update(step['id'] for chapter in p2['chapters'].values() for step in chapter['steps'])
    for row in targets:
        assert len(row['contexts']) == 3
        assert len({scene['prompt'] for scene in row['contexts']}) == 3
        for scene in row['contexts']:
            assert {('landmark_F','npc_rabbit_gardener'),('home','npc_bear_uncle'),('school','textbook_anne')} >= {(scene['room'],scene['actor'])}
            assert len(scene['options']) == 3 and len({o['id'] for o in scene['options']}) == 3
            assert sum(o['id'] == scene['correct'] for o in scene['options']) == 1
            if row['id'].removeprefix('unit/').isdigit():
                assert all(1 <= int(o['text']) <= 10 for o in scene['options'])
        if row['group'] != 'letters':
            assert all(ref in source_steps for ref in row['source_refs'])
            assert row['dimension'] == 'written_situation_choice'
    state = read(PROOF / 'state-report.json')
    assert state['result'] == 'PASS' and not state['failures']
    natives = {}
    for size in ['1440x900','960x640']:
        report = read(PROOF / size / 'report.json')
        assert report['result'] == 'PASS' and not report['failures']
        assert report['renderer'] != 'headless'
        assert len(report['screenshots']) == 16
        for path, expected in report['source_sha256'].items():
            assert digest(GAME / path) == expected, f'stale native capture: {size}/{path}'
        for name in report['screenshots']:
            assert (PROOF / size / name).stat().st_size > 1000
        natives[size] = report
    for file, marker in {
        'state-current.log':'REVISIT_STATE',
        'regression-state.log':'PASS: state persistence',
        'regression-journey.log':'728 checks, 0 failures',
        'regression-p2.log':'P2_STATE checks=284 failures=0',
        'regression-chapters.log':'P2_CHAPTERS checks=503 failures=0',
        'regression-journey-game.log':'JOURNEY_GAME_RESULT checks=189 failures=0',
        'native-1440.log':'REVISIT_NATIVE 1440x900',
        'native-960.log':'REVISIT_NATIVE 960x640',
    }.items():
        log = (PROOF / file).read_text('utf-8-sig')
        assert marker in log and 'SCRIPT ERROR' not in log and 'FAIL ' not in log and 'ERROR:' not in log, file
    chapter = read(PROOF / 'p2-chapters/chapters-1440x900-headless.json')
    journey = read(PROOF / 'journey/journey-game-1440x900-headless.json')
    assert chapter['result'] == journey['result'] == 'PASS'
    original = (GAME / 'tests/test_journey_game.gd').read_text('utf-8')
    harness = (PROOF / 'harness/journey_regression.gd').read_text('utf-8')
    assert harness == original.replace('res://../docs/verification/p2','res://../docs/verification/revisits/journey')
    allowed = {'README.md','GDD.md','game/project.godot','game/scripts/game_state.gd',
               'game/scripts/journey_controller.gd','game/scripts/main.gd','game/scripts/ui.gd',
               'game/scripts/p2_journey_controller.gd','game/ui/travel_book_view.gd'}
    protected = {}
    for path, expected in read(PROOF / 'baseline.json').items():
        source = Path(path)
        relative = source.relative_to(ROOT).as_posix() if source.is_relative_to(ROOT) else path
        if relative in allowed:
            continue
        assert digest(source) == expected, f'protected file changed: {source}'
        protected[path] = expected
    assert sum('island-save-v1.json' in key for key in protected) == 2
    content_sources = {path: digest(GAME / path) for path in ['data/learning/prologue.json','data/learning/p2_journey.json','data/curriculum.json','data/learning/catalog.json','data/learning/revisits.json']}
    report = {
        'result':'PASS','version':'0.12.0-dev','completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'targets':62,'letter_dimensions':52,'unit_situations':10,'context_variants':186,
        'state_checks':len(state['checks']),
        'native_checks':{size:len(value['checks']) for size,value in natives.items()},
        'screenshots':sum(len(r['screenshots']) for r in natives.values()),
        'regression_checks':{'journey_state':728,'p2_state':284,'chapter_flow':503,'journey_flow':189,'state_persistence':'PASS'},
        'protected_original_files':len(protected),'protected_production_saves':2,
        'runtime_sha256':natives['1440x900']['source_sha256'],'content_source_sha256':content_sources,
        'limits':['The schedule tests use synthetic clocks and fixtures, not an actual multi-day child study.',
                  'The offline local clock cannot verify clock edits while the app was closed.',
                  'Written choice and letter association do not establish listening, pronunciation or long-term mastery.',
                  'Independent teaching review, audio listening audit and child playtesting remain open.',
                  'This is an affected-scope check, not the complete project test suite or a new exported executable.'],
    }
    (PROOF / 'acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    titles = ['设置里的家长入口','尚无记录时的家长页','朋友的两份邀请','大小写选择','提示会留下记录','完成后自由离开','U1 书面新情境','首次答错之后','完整示范','家长观察总览','U1–U3 筛选','记录翻页','字母生活体验','固定形象与字母','下一轮在家里','再下一轮到校园']
    cards = []
    for size, native in natives.items():
        for name, title in zip(native['screenshots'],titles):
            src = f'verification/revisits/{size}/{name}'
            cards.append(f'<figure data-size="{size}"><a href="{src}" target="_blank"><img loading="lazy" src="{src}" alt="{html.escape(title)}"></a><figcaption>{html.escape(title)} <small>{size}</small></figcaption></figure>')
    gallery = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>字母岛 · 朋友回访与家长观察</title><style>
    *{box-sizing:border-box}body{margin:0;background:#faf6eb;color:#454a3b;font-family:"Microsoft YaHei",sans-serif}header,main{max-width:1420px;margin:auto;padding:32px}h1{font-size:34px;margin:12px 0}p{line-height:1.9;max-width:1000px}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}button,a{color:#446d51}button{border:1px solid #bdc8ae;background:#fffdf7;border-radius:10px;padding:12px 20px;cursor:pointer}button.active{background:#57765f;color:#fff}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}figure{margin:0;background:#fffdf8;border:1px solid #e4dcc8;border-radius:15px;overflow:hidden}img{display:block;width:100%;height:auto}figcaption{padding:18px;font-size:19px}small{float:right;color:#79806f;font-size:14px}[hidden]{display:none!important}@media(max-width:800px){header,main{padding:20px}.grid{grid-template-columns:1fr}h1{font-size:27px}}
    </style><header><div>LOVE STUDY / v0.12.0-dev</div><h1>朋友捎来的邀请，家长看得懂的记录</h1><p>旅行册 →「朋友捎来的小邀请」；旅行册或设置 →「家长观察册」。26 个字母的两种观察方式与 U1–U3 的 10 类书面情境已经接入。可以用提示、看示范、暂停或跳过；已有生活成果和叶币不受影响。</p><p>下面是 Godot 原生窗口的实际操作截图。使用独立测试存档，章节与过去时间为明确构造的测试数据，不是孩子的学习记录，也不是多日效果实验。<a href="verification/revisits/README.md">查看验收范围与时钟限制</a>。</p><nav><button class="active" onclick="pick('1440x900',this)">默认窗口 1440 × 900</button><button onclick="pick('960x640',this)">最小窗口 960 × 640</button><button onclick="pick('all',this)">全部画面</button></nav></header><main class="grid">'''+''.join(cards)+'''</main><script>function pick(size,button){document.querySelectorAll('figure').forEach(x=>x.hidden=size!=='all'&&x.dataset.size!==size);document.querySelectorAll('button').forEach(x=>x.classList.remove('active'));button.classList.add('active')}pick('1440x900',document.querySelector('button'))</script></html>'''
    (ROOT/'docs/revisits.html').write_text(gallery,encoding='utf-8')
    md = f'''# v0.12.0-dev · 朋友回访与家长观察

状态：**本轮工程范围 PASS**。已接入当前本地工程；双击仓库根目录的 `启动字母岛.cmd`。没有另做导出的 Windows 安装包。

## 怎么使用

- 孩子：**旅行册 → 朋友捎来的小邀请**。选择邀请，和花园的兔兔、家里的熊叔或校园的 Anne 再遇见熟悉内容。可以点提示、看示范、暂存或跳过，没有额外叶币奖励或扣罚。
- 家长：**旅行册 → 家长观察册**，也可从设置进入。按字母、U1–U3、词故事、旧情境课筛选并翻页。生活完成、首次作答、帮助和时间分别显示。
- 没有邀请时：照常玩主线或生活活动。尚未体验的字母、尚未开放的章节不会放进回访池；旧档缺少接触时间会保留未知。
- 保存失败时：提示/示范不提前露出，原尝试与旧存档保留；恢复可写路径后重试原按钮。暂停、Esc 关闭和重启会沿用同一份邀请及提示历史。

[32 张原生操作画面](../../revisits.html) · [机器验收记录](acceptance.json) · [游戏操作说明](../../Blender地图版游玩说明.md)

## 实施范围

| 内容 | 当前行为 |
|---|---|
| 26 字母 | 每字母分大小写配对、固定形象与字母两个维度，共 52 个目标；复用原固定形象 |
| U1–U3 | 问候、早安、感谢、询问名字、道别、询问年龄及 7/8/9/10 的角色年龄卡，共 10 类书面选择；数字不超出 1–10 |
| 新情境 | 每目标在花园、家里、校园有三个情境版本，共 186 个配置；不改写原 P2 尝试 |
| 调度 | 首轮隔开一个生活成果并至少一分钟，或满一个真实日后出现；此后按上轮结束后约 1、3、7 日，再按约 7 日循环 |
| 邀请数量 | 持久化的 30 分钟旅程窗口最多两份；字母和章节都有合适内容时分别提供一份；不堆积离线欠账 |
| 支持记录 | 首次错误保留；提示与示范保留；同一机会重开不重置；无提示尝试与正确性分别记录；示范不造正确作答 |
| 接触条件 | 实际字母页、相关表达、故事中实际出现的字母和候选项对相关目标留下接触记录，不标记未出现的整套内容 |
| 家长观察 | 统一现存生活事实、原字母/章节尝试及历史、词故事、早期情境课汇总和新回访；不显示掌握分数 |
| 兼容 | 新增 `reviews` 字段，缺失时安全迁移；已有旅程、成果、物品与旧学习计数保留；主文件和备份继续原事务保存 |

时间采用本机 Unix 时间，与游戏日、天气、固定白昼无关。前台墙钟与单调时钟明显不一致、回拨或超过 30 日的未知断档会使相关间隔保持未知，邀请仍可继续。**关机期间改过时钟无法由离线客户端可靠识别**，因此页面始终写“本机时钟”，不宣称可信时钟验证过的延迟回忆或学习效果。1/3/7 日与 30 分钟窗口是可调整的产品参数，不是已证明的最佳学习安排。

## 验证

| 检查 | 结果 |
|---|---|
| 新回访状态、时钟与事务 | {len(state['checks'])} 项通过；见 [state-report.json](state-report.json) |
| 默认窗口原生操作 | {len(natives['1440x900']['checks'])} 项通过；16 张截图；见 [默认窗口记录](1440x900/report.json) |
| 最小窗口原生操作 | {len(natives['960x640']['checks'])} 项通过；16 张截图；见 [小窗口记录](960x640/report.json) |
| 原状态存取与恢复 | [原状态测试通过](regression-state.log) |
| 原旅程/P2 状态 | 728 / 284 项通过 |
| 原 U2/U3 连续章节 | 503 项通过；见 [章节记录](p2-chapters/chapters-1440x900-headless.json) |
| 原序章/U1/词故事流程 | 189 项通过；复用原测试，仅改报告输出目录；见 [旅程记录](journey/journey-game-1440x900-headless.json) |
| 内容与证据一致性 | 62 个目标、186 个配置、合法选项与来源步骤、两种尺寸运行源码哈希一致 |
| 原文件保护 | 本轮起点快照中 {len(protected)} 个非目标文件保持原哈希，包含正式存档和备份 |

原生检查通过真实指针/键盘分发操作，并加载真实花园、家里和校园，检查实体朋友、提示后的恢复、写入失败、首次错误、示范、家长筛选翻页和小窗口可达性。时间调度用显式合成时钟与过去时间夹具测试，**没有等待真实 1/3/7 日，也没有开展儿童试玩**。本轮只运行受影响范围，不是全项目全量门禁。

## 核心文件与剩余范围

- [调度与校验](../../../game/scripts/review_progress.gd)、[状态事务](../../../game/scripts/game_state.gd)、[邀请与观察页](../../../game/scripts/review_controller.gd)、[观察投影](../../../game/scripts/parent_observations.gd)。
- [内容配置](../../../game/data/learning/revisits.json)与[可重复生成脚本](../../../scripts/build_review_catalog.py)；[证据核查脚本](../../../scripts/verify_revisits.py)。
- 本轮没有新录音或语音识别，没有开放口语评分。书面选择、字母对应、观看示范和生活完成不能相互替代。
- 独立教学编辑审校、人工听审、家长知情的儿童试玩，以及八册 81 章的后续制作仍分别跟踪。
'''
    (PROOF / 'README.md').write_text(md,encoding='utf-8')
    print(json.dumps({'result':'PASS','state_checks':report['state_checks'],'native_checks':report['native_checks'],'screenshots':report['screenshots'],'protected_files':len(protected)},ensure_ascii=False))

if __name__ == '__main__':
    main()
