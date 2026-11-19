"""Copy web workshop resources beside a Godot HTML export."""
import json
import shutil
import sys
from pathlib import Path

project = Path(__file__).resolve().parents[1]
assets = project / "godot/assets"
out = Path(sys.argv[1]) / "workshop"
shutil.copytree(project / "online/workshop", out, dirs_exist_ok=True)
shutil.copyfile(project / "Regolamento - Tabelle - Mappe/Scenario Generator.pdf", out / "generator.pdf")
read = lambda path: json.loads(path.read_text())
chart = read(assets / "scenarios/unit_chart.json")
support = read(assets / "scenarios/support_tables.json")
data = {"troops": {}, "support": {}}
for nation, code in dict(german="DE", italian="IT", russian="RU", french="FR", american="US", british="GB").items():
    data["support"][nation] = support[code]
    troops = list(chart["units"][code])
    leaders = [row["unita"] for row in support[code] if row.get("tipo") == "leader" and row.get("unita")]
    weapons = list(chart["weapons"][code])
    for row in support[code]:
        for key in ["unita", "arma"]:
            if row.get(key) and row[key] not in troops + leaders + weapons:
                weapons.append(row[key])
    data["troops"][nation] = troops
    data[nation] = list(dict.fromkeys(troops + leaders + weapons + ["Foxholes", "Trench", "Bunker", "Pillbox", "Wire", "Mines"]))
(out / "data.json").write_text(json.dumps(data, ensure_ascii=False))
languages = read(assets / "i18n/languages.json")
(out / "languages.json").write_text(json.dumps(languages, ensure_ascii=False))
for lang in languages:
    if not (out / (lang + ".json")).exists():
        shutil.copyfile(out / "en.json", out / (lang + ".json"))
    messages = read(out / (lang + ".json"))
    game = read(assets / ("i18n/" + lang + ".json"))
    for names in (v for v in data.values() if isinstance(v, list)):
        for name in names:
            messages.setdefault(name, game.get(name, name))
    (out / (lang + ".json")).write_text(json.dumps(messages, ensure_ascii=False, indent=2))
charts = project / "CombatCommanderEurope-2.6.2/images/Chart"
(out / "charts").mkdir(exist_ok=True)
for nation, title in dict(german="German", russian="Russian", american="American", british="British Commonwealth", italian="Italian Axis Minors", french="French Allied Minors").items():
    for slug, suffix in [("ob", "Order of Battle"), ("support", "Support Table")]:
        shutil.copyfile(charts / f"CC {title} {suffix}.jpg", out / "charts" / f"{nation}-{slug}.jpg")
shutil.copyfile(charts / "RSG Leader Table.jpg", out / "charts/leaders.jpg")
