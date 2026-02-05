#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"

SUITS_TO_UPDATE = ("major", "wands", "cups")

SUIT_FORMS = {
    "en": {"wands": "Wands", "cups": "Cups"},
    "ru": {"wands": "Жезлах", "cups": "Кубках"},
    "kk": {"wands": "Таяқтардың", "cups": "Кубоктардың"},
}

MINOR_FUN_FACTS = {
    "en": {
        "ace": "Aces in {suit} are the first pulse of the element.",
        "two": "Twos in {suit} highlight balance and early partnership.",
        "three": "Threes in {suit} mark growth and the first results.",
        "four": "Fours in {suit} bring stability and a needed pause.",
        "five": "Fives in {suit} introduce friction that tests resolve.",
        "six": "Sixes in {suit} show progress and shared momentum.",
        "seven": "Sevens in {suit} signal tests of focus and stamina.",
        "eight": "Eights in {suit} accelerate movement and decisive action.",
        "nine": "Nines in {suit} reflect resilience near the finish.",
        "ten": "Tens in {suit} close the cycle with full weight.",
        "page": "Pages in {suit} point to learning, news, and curiosity.",
        "knight": "Knights in {suit} act fast, driven by the suit's energy.",
        "queen": "Queens in {suit} hold power inward with steady control.",
        "king": "Kings in {suit} express mastery outwardly and confidently.",
    },
    "ru": {
        "ace": "Тузы в {suit} — первый импульс стихии.",
        "two": "Двойки в {suit} про баланс и ранний союз.",
        "three": "Тройки в {suit} отмечают рост и первые результаты.",
        "four": "Четверки в {suit} дают стабильность и паузу.",
        "five": "Пятерки в {suit} вносят трение и проверку.",
        "six": "Шестерки в {suit} показывают прогресс и поддержку.",
        "seven": "Семерки в {suit} проверяют фокус и выносливость.",
        "eight": "Восьмерки в {suit} ускоряют движение и решения.",
        "nine": "Девятки в {suit} про стойкость перед финишем.",
        "ten": "Десятки в {suit} закрывают цикл с полной нагрузкой.",
        "page": "Пажи в {suit} — обучение, новости, любопытство.",
        "knight": "Рыцари в {suit} действуют быстро, ведомые энергией масти.",
        "queen": "Королевы в {suit} держат силу внутри, спокойно и твердо.",
        "king": "Короли в {suit} выражают мастерство уверенно и вовне.",
    },
    "kk": {
        "ace": "{suit} туздары — стихияның алғашқы импульсі.",
        "two": "{suit} екілігі тепе-теңдік пен алғашқы серіктестік туралы.",
        "three": "{suit} үштігі өсу мен алғашқы нәтижені көрсетеді.",
        "four": "{suit} төрттігі тұрақтылық пен үзіліс береді.",
        "five": "{suit} бестігі үйкеліс пен сынақты әкеледі.",
        "six": "{suit} алтылығы ілгерілеу мен ортақ серпін.",
        "seven": "{suit} жетілігі назар мен төзімділікті тексереді.",
        "eight": "{suit} сегіздігі қозғалыс пен шешімді үдетеді.",
        "nine": "{suit} тоғыздығы мәреге таяған төзімділік.",
        "ten": "{suit} ондығы циклды толық салмақпен жабады.",
        "page": "{suit} паждары — үйрену, хабар және қызығушылық.",
        "knight": "{suit} серілері жылдам қимылдап, масть қуатымен жүреді.",
        "queen": "{suit} ханымдары күшті іште ұстап, сабырлы басқарады.",
        "king": "{suit} патшалары шеберлікті сыртқа сенімді шығарады.",
    },
}

MAJOR_FUN_FACTS = {
    "en": {
        "major_00_fool": "The Fool opens the journey with risk and curiosity.",
        "major_01_magician": "The Magician is the first figure to claim personal power.",
        "major_02_high_priestess": "The High Priestess guards knowledge that isn't spoken.",
        "major_03_empress": "The Empress represents creation, comfort, and embodied care.",
        "major_04_emperor": "The Emperor is the archetype of structure and authority.",
        "major_05_hierophant": "The Hierophant points to tradition and shared systems.",
        "major_06_lovers": "The Lovers centers on alignment before commitment.",
        "major_07_chariot": "The Chariot is about willpower steering opposing forces.",
        "major_08_strength": "Strength highlights calm control rather than brute force.",
        "major_09_hermit": "The Hermit steps back to find a private light.",
        "major_10_wheel_of_fortune": "The Wheel of Fortune speaks to cycles you can't fully steer.",
        "major_11_justice": "Justice weighs actions with clear consequences.",
        "major_12_hanged_man": "The Hanged Man flips the view to unlock insight.",
        "major_13_death": "Death marks an ending that makes room for the next phase.",
        "major_14_temperance": "Temperance is the art of blending extremes into balance.",
        "major_15_devil": "The Devil exposes attachments that feel like control.",
        "major_16_tower": "The Tower breaks what is unstable so truth can surface.",
        "major_17_star": "The Star is a quiet promise of renewal.",
        "major_18_moon": "The Moon rules the night of doubt and intuition.",
        "major_19_sun": "The Sun brings clarity, warmth, and visible results.",
        "major_20_judgement": "Judgement is a call to answer for who you've become.",
        "major_21_world": "The World closes a cycle with earned completion.",
    },
    "ru": {
        "major_00_fool": "Шут открывает путь с риском и любопытством.",
        "major_01_magician": "Маг — первая фигура, заявляющая личную силу.",
        "major_02_high_priestess": "Верховная Жрица хранит знание, о котором не говорят.",
        "major_03_empress": "Императрица — про создание, комфорт и заботу тела.",
        "major_04_emperor": "Император — архетип структуры и власти.",
        "major_05_hierophant": "Иерофант указывает на традиции и общие правила.",
        "major_06_lovers": "Влюбленные — о согласии перед выбором.",
        "major_07_chariot": "Колесница — воля, управляющая противоречиями.",
        "major_08_strength": "Сила — спокойный контроль вместо грубой мощи.",
        "major_09_hermit": "Отшельник отходит в тень ради внутреннего света.",
        "major_10_wheel_of_fortune": "Колесо Фортуны — о циклах, которые не удержать.",
        "major_11_justice": "Справедливость взвешивает поступки и последствия.",
        "major_12_hanged_man": "Повешенный переворачивает взгляд ради инсайта.",
        "major_13_death": "Смерть отмечает конец, освобождающий место новому.",
        "major_14_temperance": "Умеренность — искусство смешивать крайности.",
        "major_15_devil": "Дьявол показывает привязки, похожие на контроль.",
        "major_16_tower": "Башня ломает шаткое, чтобы проявилась правда.",
        "major_17_star": "Звезда — тихое обещание обновления.",
        "major_18_moon": "Луна правит ночью сомнений и интуиции.",
        "major_19_sun": "Солнце приносит ясность, тепло и заметный результат.",
        "major_20_judgement": "Суд — вызов ответить за то, кем вы стали.",
        "major_21_world": "Мир закрывает цикл заслуженным завершением.",
    },
    "kk": {
        "major_00_fool": "Ақымақ сапарды тәуекел мен қызығушылықпен ашады.",
        "major_01_magician": "Сиқыршы — жеке күшті алғаш жариялайтын бейне.",
        "major_02_high_priestess": "Жоғарғы Жрица айтылмайтын білімді сақтайды.",
        "major_03_empress": "Императрица — жарату, жайлылық және тән қамқорлығы.",
        "major_04_emperor": "Император — құрылым мен биліктің архетипі.",
        "major_05_hierophant": "Иерофант дәстүр мен ортақ қағидаларды меңзейді.",
        "major_06_lovers": "Ғашықтар — таңдаудан бұрынғы үйлесім туралы.",
        "major_07_chariot": "Арба — ерік қарсы күштерді басқарғанда.",
        "major_08_strength": "Күш — дөрекі қуат емес, сабырлы бақылау.",
        "major_09_hermit": "Тақуа ішкі жарық үшін шетке шегінеді.",
        "major_10_wheel_of_fortune": "Бақыт Дөңгелегі — ұстап тұра алмайтын циклдар жайлы.",
        "major_11_justice": "Әділет әрекет пен салдарды тең өлшейді.",
        "major_12_hanged_man": "Асылған — басқа қырды көру үшін көзқарасты аудару.",
        "major_13_death": "Өлім — жаңа кезеңге орын ашатын аяқталу.",
        "major_14_temperance": "Ұстамдылық — шектілерді үйлестіру өнері.",
        "major_15_devil": "Ібіліс бақылауға ұқсайтын тәуелділікті ашады.",
        "major_16_tower": "Мұнара орнықсызды бұзып, ақиқатты шығарады.",
        "major_17_star": "Жұлдыз — жаңарудың тыныш уәдесі.",
        "major_18_moon": "Ай — күмән мен түйсік түнін басқарады.",
        "major_19_sun": "Күн — айқындық, жылу және көрінетін нәтиже.",
        "major_20_judgement": "Сот — кімге айналғаныңызға жауап беру шақыруы.",
        "major_21_world": "Әлем — еңбектің аяқталған толық циклі.",
    },
}


def ensure_sentence(text: str) -> str:
    value = text.strip()
    if not value.endswith((".", "!", "?")):
        value = f"{value}."
    return value


def build_detailed(meaning: dict[str, str]) -> str:
    parts = [meaning["general"], meaning["light"], meaning["shadow"], meaning["advice"]]
    return " ".join(ensure_sentence(part) for part in parts)


def build_fun_fact(locale: str, card_id: str) -> str:
    if card_id.startswith("major_"):
        return MAJOR_FUN_FACTS[locale][card_id]
    suit = card_id.split("_", 1)[0]
    rank = card_id.split("_", 2)[2]
    template = MINOR_FUN_FACTS[locale][rank]
    return template.format(suit=SUIT_FORMS[locale][suit])


def update_locale(locale: str) -> int:
    path = DATA_DIR / f"cards_{locale}.json"
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    updated = 0
    for card_id, card in data.items():
        suit = card_id.split("_", 1)[0]
        if suit not in SUITS_TO_UPDATE:
            continue
        card["detailedDescription"] = build_detailed(card["meaning"])
        card["funFact"] = build_fun_fact(locale, card_id)
        updated += 1

    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    return updated


def main() -> None:
    total = 0
    for locale in ("en", "ru", "kk"):
        total += update_locale(locale)
    print(f"Updated {total} cards with detailed descriptions and fun facts.")


if __name__ == "__main__":
    main()
