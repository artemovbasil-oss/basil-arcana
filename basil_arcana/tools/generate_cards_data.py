#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CDN_DATA_DIR = ROOT / "cdn" / "data"
APP_DATA_DIR = ROOT / "app_flutter" / "assets" / "data"
LOCALE_FILE_MAP = {"en": "en", "ru": "ru", "kk": "kz"}


@dataclass(frozen=True)
class MajorCardLocale:
    title: str
    keywords: list[str]
    general: str
    light: str
    shadow: str
    advice: str
    fact: str


MAJOR_CARDS: dict[str, dict[str, MajorCardLocale]] = {
    "major_00_fool": {
        "en": MajorCardLocale(
            title="The Fool",
            keywords=["beginnings", "freedom", "trust"],
            general="A fresh start and a leap of faith.",
            light="Playful optimism and a willingness to explore.",
            shadow="Naivety, rash risks, or ignoring the obvious.",
            advice="Begin, but carry a small plan with your hope.",
            fact="Numbered 0, The Fool is the journey before it starts.",
        ),
        "ru": MajorCardLocale(
            title="Шут",
            keywords=["начало", "свобода", "доверие"],
            general="Свежий старт и шаг в неизвестность.",
            light="Игривый оптимизм и готовность исследовать.",
            shadow="Наивность, риск без опоры, игнор очевидного.",
            advice="Начните, но захватите с собой план.",
            fact="Шут под номером 0 — путь до самого пути.",
        ),
        "kk": MajorCardLocale(
            title="Ақымақ",
            keywords=["бастау", "еркіндік", "сенім"],
            general="Жаңа бастау және белгісізге қадам.",
            light="Ойыншыл оптимизм мен зерттеуге ашықтық.",
            shadow="Аңғалдық, дайындығы жоқ тәуекел, айқын нәрсені байқамау.",
            advice="Бастаңыз, бірақ шағын жоспарды қоса алыңыз.",
            fact="0-нөмірлі Ақымақ — жол басталар алдындағы бейне.",
        ),
    },
    "major_01_magician": {
        "en": MajorCardLocale(
            title="The Magician",
            keywords=["will", "skill", "manifestation"],
            general="Focused will and the tools to make ideas real.",
            light="Confidence, skill, and aligned action.",
            shadow="Manipulation or scattered energy.",
            advice="Pick one aim and commit your resources.",
            fact="The Magician holds all four suit symbols on the table.",
        ),
        "ru": MajorCardLocale(
            title="Маг",
            keywords=["воля", "мастерство", "проявление"],
            general="Сфокусированная воля и инструменты для воплощения.",
            light="Уверенность, навык и согласованные действия.",
            shadow="Манипуляция или распыление энергии.",
            advice="Выберите одну цель и соберите ресурсы.",
            fact="У Мага на столе присутствуют символы всех мастей.",
        ),
        "kk": MajorCardLocale(
            title="Сиқыршы",
            keywords=["ерік", "шеберлік", "іске асыру"],
            general="Шоғырланған ерік пен идеяны іске асыратын құралдар.",
            light="Сенім, шеберлік және үйлесімді әрекет.",
            shadow="Манипуляция немесе шашыраған қуат.",
            advice="Бір мақсатты таңдаңыз да, ресурстарды соған жинаңыз.",
            fact="Сиқыршы үстелінде төрт мастьтың да белгісі бар.",
        ),
    },
    "major_02_high_priestess": {
        "en": MajorCardLocale(
            title="The High Priestess",
            keywords=["intuition", "mystery", "inner voice"],
            general="Quiet knowledge and the pull of intuition.",
            light="Trusting subtle signals and inner truth.",
            shadow="Withholding, secrecy, or ignoring feelings.",
            advice="Listen before you speak or act.",
            fact="She sits between pillars marked for the seen and unseen.",
        ),
        "ru": MajorCardLocale(
            title="Верховная Жрица",
            keywords=["интуиция", "тайна", "внутренний голос"],
            general="Тихое знание и зов интуиции.",
            light="Доверие тонким сигналам и внутренней правде.",
            shadow="Закрытость, тайна или игнор чувств.",
            advice="Сначала слушайте, затем действуйте.",
            fact="Жрица сидит между столпами видимого и скрытого.",
        ),
        "kk": MajorCardLocale(
            title="Жоғарғы Жрица",
            keywords=["түйсік", "құпия", "ішкі дауыс"],
            general="Тыныш білім және түйсіктің шақыруы.",
            light="Нәзік белгілерге және ішкі ақиқатқа сену.",
            shadow="Жабықтық, құпия сақтау немесе сезімді елемеу.",
            advice="Айтпас бұрын тыңдаңыз.",
            fact="Жрица көрінетін және көрінбейтіннің бағандарының арасында отырады.",
        ),
    },
    "major_03_empress": {
        "en": MajorCardLocale(
            title="The Empress",
            keywords=["nurture", "abundance", "creation"],
            general="Abundance, care, and embodied creativity.",
            light="Warmth, growth, and fertile ideas.",
            shadow="Overgiving or being smothered by comfort.",
            advice="Feed what you want to grow.",
            fact="The Empress is linked to Venus and the earth.",
        ),
        "ru": MajorCardLocale(
            title="Императрица",
            keywords=["забота", "изобилие", "созидание"],
            general="Изобилие, забота и творческая плоть.",
            light="Тепло, рост и плодородные идеи.",
            shadow="Чрезмерная опека или зависимость от комфорта.",
            advice="Питайте то, что хотите вырастить.",
            fact="Императрица связана с Венерой и землей.",
        ),
        "kk": MajorCardLocale(
            title="Императрица",
            keywords=["қамқорлық", "молшылық", "жарату"],
            general="Молшылық, қамқорлық және тәндік шығармашылық.",
            light="Жылу, өсу және құнарлы идеялар.",
            shadow="Шектен тыс қамқорлық немесе жайлылыққа байланып қалу.",
            advice="Өсіргіңіз келетін нәрсені қоректендіріңіз.",
            fact="Императрица Венерамен және жермен байланысты.",
        ),
    },
    "major_04_emperor": {
        "en": MajorCardLocale(
            title="The Emperor",
            keywords=["structure", "authority", "stability"],
            general="Order, structure, and responsible leadership.",
            light="Clear boundaries and steady authority.",
            shadow="Rigidity, control, or fear of change.",
            advice="Lead with firmness and fairness.",
            fact="The Emperor embodies the stabilizing force of Aries.",
        ),
        "ru": MajorCardLocale(
            title="Император",
            keywords=["структура", "власть", "стабильность"],
            general="Порядок, структура и ответственное лидерство.",
            light="Четкие границы и спокойная власть.",
            shadow="Жесткость, контроль или страх перемен.",
            advice="Ведите твердо, но справедливо.",
            fact="Император связан с энергией Овна.",
        ),
        "kk": MajorCardLocale(
            title="Император",
            keywords=["құрылым", "билік", "тұрақтылық"],
            general="Тәртіп, құрылым және жауапты басшылық.",
            light="Айқын шекара және орнықты билік.",
            shadow="Қаттылық, бақылау немесе өзгерістен қорқу.",
            advice="Қатал емес, әділ басқарыңыз.",
            fact="Император Тоқты энергиясымен байланысты.",
        ),
    },
    "major_05_hierophant": {
        "en": MajorCardLocale(
            title="The Hierophant",
            keywords=["tradition", "beliefs", "guidance"],
            general="Shared values, tradition, and learning from elders.",
            light="Mentorship, ritual, and steady teachings.",
            shadow="Dogma, conformity, or resisting growth.",
            advice="Honor the lesson, then make it your own.",
            fact="The Hierophant bridges the sacred and the social.",
        ),
        "ru": MajorCardLocale(
            title="Иерофант",
            keywords=["традиция", "убеждения", "наставник"],
            general="Общие ценности, традиции и обучение у старших.",
            light="Наставничество, ритуал и устойчивые знания.",
            shadow="Догма, конформизм или сопротивление росту.",
            advice="Уважайте урок, затем сделайте его своим.",
            fact="Иерофант соединяет священное и общественное.",
        ),
        "kk": MajorCardLocale(
            title="Иерофант",
            keywords=["дәстүр", "сенім", "бағыт"],
            general="Ортақ құндылықтар, дәстүр және ұстаздан үйрену.",
            light="Тәлімгерлік, рәсім және орнықты білім.",
            shadow="Догма, бірізділікке мәжбүрлеу немесе өсуді тежеу.",
            advice="Сабақты құрметтеңіз, кейін өз жолыңызға икемдеңіз.",
            fact="Иерофант қасиетті мен қоғамдықтың арасын байланыстырады.",
        ),
    },
    "major_06_lovers": {
        "en": MajorCardLocale(
            title="The Lovers",
            keywords=["alignment", "choice", "union"],
            general="Alignment of values before commitment.",
            light="Mutual choice, harmony, and honest connection.",
            shadow="Indecision, temptation, or values out of sync.",
            advice="Choose what truly matches your heart.",
            fact="The Lovers are about alignment more than romance.",
        ),
        "ru": MajorCardLocale(
            title="Влюбленные",
            keywords=["согласие", "выбор", "союз"],
            general="Согласование ценностей перед выбором.",
            light="Взаимный выбор, гармония и честная связь.",
            shadow="Нерешительность, искушение или конфликт ценностей.",
            advice="Выберите то, что действительно откликается сердцу.",
            fact="Карта о согласии и выборе, а не только о любви.",
        ),
        "kk": MajorCardLocale(
            title="Ғашықтар",
            keywords=["үйлесім", "таңдау", "бірлік"],
            general="Міндеттен бұрын құндылықтардың үйлесуі.",
            light="Өзара таңдау, гармония және адал байланыс.",
            shadow="Шешімсіздік, арбау немесе құндылықтың сәйкес келмеуі.",
            advice="Шын жүрегіңізге сай таңдаңыз.",
            fact="Ғашықтар — үйлесім мен таңдауды бейнелейді.",
        ),
    },
    "major_07_chariot": {
        "en": MajorCardLocale(
            title="The Chariot",
            keywords=["willpower", "direction", "victory"],
            general="Discipline and will guiding opposing forces.",
            light="Momentum, confidence, and steady drive.",
            shadow="Aggression, scattered focus, or forcing outcomes.",
            advice="Hold the reins and steer with purpose.",
            fact="The Chariot is linked to the sign of Cancer.",
        ),
        "ru": MajorCardLocale(
            title="Колесница",
            keywords=["воля", "курс", "победа"],
            general="Дисциплина и воля, направляющие разные силы.",
            light="Импульс, уверенность и устойчивый рывок.",
            shadow="Агрессия, расфокус или давление на результат.",
            advice="Держите поводья и ведите осознанно.",
            fact="Колесница связана со знаком Рака.",
        ),
        "kk": MajorCardLocale(
            title="Арба",
            keywords=["ерік", "бағыт", "жеңіс"],
            general="Қарама-қарсы күштерді ерікпен басқару.",
            light="Серпін, сенім және тұрақты ілгерілеу.",
            shadow="Агрессия, назардың шашырауы немесе нәтижені күштеу.",
            advice="Тізгінді берік ұстап, мақсатпен бағыттаңыз.",
            fact="Арба Шаян белгісімен байланысты.",
        ),
    },
    "major_08_strength": {
        "en": MajorCardLocale(
            title="Strength",
            keywords=["courage", "patience", "compassion"],
            general="Gentle power and steady inner courage.",
            light="Calm resilience and compassionate control.",
            shadow="Self-doubt, suppressed anger, or forcing calm.",
            advice="Lead with patience, not pressure.",
            fact="Strength is associated with the sign of Leo.",
        ),
        "ru": MajorCardLocale(
            title="Сила",
            keywords=["мужество", "терпение", "сострадание"],
            general="Мягкая сила и внутренняя устойчивость.",
            light="Спокойная стойкость и сострадательный контроль.",
            shadow="Сомнения, подавленная злость или натянутое спокойствие.",
            advice="Действуйте терпеливо, а не давя.",
            fact="Сила связана со знаком Льва.",
        ),
        "kk": MajorCardLocale(
            title="Күш",
            keywords=["батылдық", "сабыр", "жанашырлық"],
            general="Нәзік қуат пен ішкі табандылық.",
            light="Сабырлы төзім және жанашыр бақылау.",
            shadow="Өзіңе сенбеу, басылған ашу немесе күшпен тынышталу.",
            advice="Қысым емес, сабырмен бастаңыз.",
            fact="Күш Арыстан белгісімен байланысты.",
        ),
    },
    "major_09_hermit": {
        "en": MajorCardLocale(
            title="The Hermit",
            keywords=["solitude", "wisdom", "guidance"],
            general="Withdrawal to find inner guidance.",
            light="Reflection, clarity, and honest self-study.",
            shadow="Isolation, avoidance, or withdrawing too long.",
            advice="Step back to see the path clearly.",
            fact="The Hermit carries a lantern to light the way.",
        ),
        "ru": MajorCardLocale(
            title="Отшельник",
            keywords=["уединение", "мудрость", "наставление"],
            general="Уход внутрь ради внутреннего света.",
            light="Размышление, ясность и честный самоанализ.",
            shadow="Изоляция, избегание или затяжной уход.",
            advice="Отступите, чтобы увидеть путь.",
            fact="Отшельник несет фонарь как знак внутреннего света.",
        ),
        "kk": MajorCardLocale(
            title="Тақуа",
            keywords=["жалғыздық", "даналық", "бағдар"],
            general="Ішкі бағыт табу үшін шегіну.",
            light="Ойлану, айқындық және адал өзін зерттеу.",
            shadow="Оқшаулану, қашу немесе тым ұзақ шегіну.",
            advice="Жолды көру үшін бір қадам артқа шегініңіз.",
            fact="Тақуаның қолында жолды жарықтандыратын шам бар.",
        ),
    },
    "major_10_wheel": {
        "en": MajorCardLocale(
            title="Wheel of Fortune",
            keywords=["cycles", "change", "fate"],
            general="A turning cycle and shifting circumstances.",
            light="Positive momentum and welcome change.",
            shadow="Feeling stuck in a loop or resisting the turn.",
            advice="Move with the change instead of fighting it.",
            fact="The wheel reminds us that everything turns.",
        ),
        "ru": MajorCardLocale(
            title="Колесо Фортуны",
            keywords=["циклы", "перемены", "судьба"],
            general="Поворот цикла и смена обстоятельств.",
            light="Позитивный импульс и удачные перемены.",
            shadow="Ощущение замкнутого круга или сопротивление повороту.",
            advice="Двигайтесь вместе с переменами.",
            fact="Колесо напоминает, что все вращается.",
        ),
        "kk": MajorCardLocale(
            title="Бақыт Дөңгелегі",
            keywords=["цикл", "өзгеріс", "тағдыр"],
            general="Циклдың бұрылуы және жағдайдың ауысуы.",
            light="Жағымды серпін мен тиімді өзгеріс.",
            shadow="Шеңберден шыға алмау сезімі немесе бұрылуға қарсы тұру.",
            advice="Өзгеріспен бірге қозғалыңыз.",
            fact="Дөңгелек бәрі айналып тұратынын еске салады.",
        ),
    },
    "major_11_justice": {
        "en": MajorCardLocale(
            title="Justice",
            keywords=["truth", "balance", "accountability"],
            general="Clarity, fairness, and consequences.",
            light="Honesty, integrity, and balanced judgment.",
            shadow="Bias, denial, or fear of truth.",
            advice="Tell the truth and accept what it brings.",
            fact="Justice is linked to the sign of Libra.",
        ),
        "ru": MajorCardLocale(
            title="Справедливость",
            keywords=["истина", "баланс", "ответственность"],
            general="Ясность, справедливость и последствия.",
            light="Честность, целостность и взвешенное решение.",
            shadow="Предвзятость, отрицание или страх правды.",
            advice="Говорите правду и принимайте последствия.",
            fact="Справедливость связана со знаком Весов.",
        ),
        "kk": MajorCardLocale(
            title="Әділет",
            keywords=["ақиқат", "теңдік", "жауапкершілік"],
            general="Айқындық, әділдік және салдар.",
            light="Адалдық, тұтастық және тең өлшем.",
            shadow="Бейтарапсыздық, жоққа шығару немесе шындықтан қорқу.",
            advice="Шындықты айтып, салдарын қабылдаңыз.",
            fact="Әділет Таразы белгісімен байланысты.",
        ),
    },
    "major_12_hanged_man": {
        "en": MajorCardLocale(
            title="The Hanged Man",
            keywords=["pause", "surrender", "perspective"],
            general="A pause that reveals a new view.",
            light="Letting go to gain insight.",
            shadow="Stalling, martyrdom, or fear of change.",
            advice="Release control and see what shifts.",
            fact="The Hanged Man is about perspective, not punishment.",
        ),
        "ru": MajorCardLocale(
            title="Повешенный",
            keywords=["пауза", "отпускание", "взгляд"],
            general="Пауза, открывающая новый ракурс.",
            light="Отпустить ради инсайта.",
            shadow="Зависание, жертвенность или страх перемен.",
            advice="Отпустите контроль и наблюдайте за сдвигом.",
            fact="Повешенный — о смене взгляда, а не наказании.",
        ),
        "kk": MajorCardLocale(
            title="Асылған",
            keywords=["үзіліс", "жіберу", "көзқарас"],
            general="Жаңа қырды көрсететін үзіліс.",
            light="Түсінік үшін жіберу.",
            shadow="Тоқырау, өзін құрбан ету немесе өзгерістен қорқу.",
            advice="Бақылауды босатып, өзгерісті көріңіз.",
            fact="Асылған — жазалау емес, көзқарасты ауыстыру.",
        ),
    },
    "major_13_death": {
        "en": MajorCardLocale(
            title="Death",
            keywords=["ending", "transformation", "renewal"],
            general="An ending that clears the way forward.",
            light="Release, renewal, and true transformation.",
            shadow="Clinging to the past or fearing change.",
            advice="Let the old fall away so the new can rise.",
            fact="Death is tied to Scorpio and deep change.",
        ),
        "ru": MajorCardLocale(
            title="Смерть",
            keywords=["конец", "преобразование", "обновление"],
            general="Завершение, освобождающее путь.",
            light="Освобождение, обновление и глубокая трансформация.",
            shadow="Цепляние за прошлое или страх перемен.",
            advice="Позвольте старому уйти, чтобы пришло новое.",
            fact="Смерть связана со Скорпионом и глубокой сменой.",
        ),
        "kk": MajorCardLocale(
            title="Өлім",
            keywords=["аяқталу", "түрлену", "жаңару"],
            general="Алға жол ашатын аяқталу.",
            light="Босату, жаңару және шынайы түрлену.",
            shadow="Өткенге жабысып қалу немесе өзгерістен қорқу.",
            advice="Ескі кеткенде, жаңаның келуіне орын қалсын.",
            fact="Өлім Скорпионмен және терең өзгеріспен байланысты.",
        ),
    },
    "major_14_temperance": {
        "en": MajorCardLocale(
            title="Temperance",
            keywords=["balance", "healing", "integration"],
            general="Blending extremes into harmony.",
            light="Patience, healing, and steady integration.",
            shadow="Imbalance, excess, or forcing a mix.",
            advice="Go slowly and let the blend settle.",
            fact="Temperance is linked to the sign of Sagittarius.",
        ),
        "ru": MajorCardLocale(
            title="Умеренность",
            keywords=["баланс", "исцеление", "синтез"],
            general="Смешивание крайностей в гармонию.",
            light="Терпение, исцеление и плавная интеграция.",
            shadow="Дисбаланс, излишества или насильственный микс.",
            advice="Двигайтесь медленно и дайте смеси созреть.",
            fact="Умеренность связана со знаком Стрельца.",
        ),
        "kk": MajorCardLocale(
            title="Ұстамдылық",
            keywords=["теңдік", "сауықтыру", "үйлестіру"],
            general="Шектілерді үйлесімге араластыру.",
            light="Сабыр, сауығу және біртіндеп біріктіру.",
            shadow="Теңсіздік, артықтық немесе күшпен араластыру.",
            advice="Асықпай, араласуға уақыт беріңіз.",
            fact="Ұстамдылық Мерген белгісімен байланысты.",
        ),
    },
    "major_15_devil": {
        "en": MajorCardLocale(
            title="The Devil",
            keywords=["attachment", "temptation", "control"],
            general="Attachments that feel like control.",
            light="Awareness of what binds you.",
            shadow="Addiction, fear, or giving away power.",
            advice="Name the chain, then loosen it.",
            fact="The Devil mirrors the Lovers, but without choice.",
        ),
        "ru": MajorCardLocale(
            title="Дьявол",
            keywords=["привязка", "искушение", "контроль"],
            general="Привязки, похожие на контроль.",
            light="Осознание того, что держит.",
            shadow="Зависимость, страх или отдача силы.",
            advice="Назовите цепь и ослабьте ее.",
            fact="Дьявол — перевернутые Влюбленные без выбора.",
        ),
        "kk": MajorCardLocale(
            title="Ібіліс",
            keywords=["тәуелділік", "арбау", "бақылау"],
            general="Бақылауға ұқсайтын тәуелді байланыс.",
            light="Не нәрсе байлап тұрғанын ұғыну.",
            shadow="Тәуелділік, қорқыныш немесе күшті беру.",
            advice="Тізбекті атаңыз да, босатыңыз.",
            fact="Ібіліс — таңдау жоқ Ғашықтардың айнасы.",
        ),
    },
    "major_16_tower": {
        "en": MajorCardLocale(
            title="The Tower",
            keywords=["upheaval", "truth", "release"],
            general="A sudden shake that reveals truth.",
            light="Breakthrough, liberation, and clarity.",
            shadow="Chaos, resistance, or fear of collapse.",
            advice="Let the false fall so the real can stand.",
            fact="The Tower is linked to Mars and abrupt change.",
        ),
        "ru": MajorCardLocale(
            title="Башня",
            keywords=["потрясение", "правда", "освобождение"],
            general="Внезапный удар, открывающий правду.",
            light="Прорыв, освобождение и ясность.",
            shadow="Хаос, сопротивление или страх падения.",
            advice="Позвольте ложному рухнуть, чтобы осталось истинное.",
            fact="Башня связана с Марсом и резкими переменами.",
        ),
        "kk": MajorCardLocale(
            title="Мұнара",
            keywords=["сілкініс", "ақиқат", "босату"],
            general="Кенет өзгеріс ақиқатты ашады.",
            light="Бұзу арқылы ашылу, босану және айқындық.",
            shadow="Аласапыран, қарсыласу немесе құлаудан қорқу.",
            advice="Жалған құласын — шынайысы қалсын.",
            fact="Мұнара Марспен және күрт өзгеріспен байланысты.",
        ),
    },
    "major_17_star": {
        "en": MajorCardLocale(
            title="The Star",
            keywords=["hope", "healing", "renewal"],
            general="A quiet promise of renewal.",
            light="Hope, calm faith, and healing.",
            shadow="Doubt, discouragement, or losing faith.",
            advice="Keep the signal alive, even if it is small.",
            fact="The Star follows the Tower as a sign of recovery.",
        ),
        "ru": MajorCardLocale(
            title="Звезда",
            keywords=["надежда", "исцеление", "обновление"],
            general="Тихое обещание обновления.",
            light="Надежда, спокойная вера и исцеление.",
            shadow="Сомнения, уныние или потеря веры.",
            advice="Поддерживайте свет, даже если он мал.",
            fact="Звезда приходит после Башни как знак восстановления.",
        ),
        "kk": MajorCardLocale(
            title="Жұлдыз",
            keywords=["үміт", "сауығу", "жаңару"],
            general="Жаңарудың тыныш уәдесі.",
            light="Үміт, сабырлы сенім және сауығу.",
            shadow="Күмән, жігерсіздік немесе сенім жоғалту.",
            advice="Шағын болса да жарықты сақтаңыз.",
            fact="Жұлдыз Мұнарадан кейін қалпына келудің белгісі.",
        ),
    },
    "major_18_moon": {
        "en": MajorCardLocale(
            title="The Moon",
            keywords=["mystery", "dreams", "uncertainty"],
            general="The fog of intuition and the unseen.",
            light="Imagination, empathy, and subtle guidance.",
            shadow="Confusion, fear, or illusion.",
            advice="Move slowly and verify what you feel.",
            fact="The Moon rules the tides of the unconscious.",
        ),
        "ru": MajorCardLocale(
            title="Луна",
            keywords=["тайна", "сны", "неопределенность"],
            general="Туман интуиции и скрытого.",
            light="Воображение, эмпатия и тонкое руководство.",
            shadow="Смятение, страх или иллюзия.",
            advice="Идите медленно и проверяйте ощущения.",
            fact="Луна управляет приливами бессознательного.",
        ),
        "kk": MajorCardLocale(
            title="Ай",
            keywords=["құпия", "түс", "белгісіздік"],
            general="Түйсіктің тұманы және көрінбейтін дүние.",
            light="Қиял, эмпатия және нәзік бағыт.",
            shadow="Бейберекет, қорқыныш немесе елес.",
            advice="Баяу қимылдап, сезімді тексеріңіз.",
            fact="Ай бейсананың толқындарын басқарады.",
        ),
    },
    "major_19_sun": {
        "en": MajorCardLocale(
            title="The Sun",
            keywords=["joy", "clarity", "success"],
            general="Warmth, visibility, and clear success.",
            light="Joy, vitality, and honest celebration.",
            shadow="Overexposure, ego, or burnout.",
            advice="Let your light be seen and shared.",
            fact="The Sun is the clearest card of the deck.",
        ),
        "ru": MajorCardLocale(
            title="Солнце",
            keywords=["радость", "ясность", "успех"],
            general="Тепло, видимость и ясный успех.",
            light="Радость, жизненная сила и открытое празднование.",
            shadow="Слишком ярко, эго или выгорание.",
            advice="Позвольте свету быть видимым.",
            fact="Солнце — самая ясная карта колоды.",
        ),
        "kk": MajorCardLocale(
            title="Күн",
            keywords=["қуаныш", "айқындық", "табыс"],
            general="Жылу, көрінушілік және айқын табыс.",
            light="Қуаныш, өміршеңдік және ашық мереке.",
            shadow="Тым жарқырау, эго немесе шаршау.",
            advice="Жарығыңызды бөлісіңіз.",
            fact="Күн — колодадағы ең айқын карта.",
        ),
    },
    "major_20_judgement": {
        "en": MajorCardLocale(
            title="Judgement",
            keywords=["awakening", "reckoning", "purpose"],
            general="A call to rise and be accountable.",
            light="Renewal, forgiveness, and clear purpose.",
            shadow="Harsh self-judgment or refusing the call.",
            advice="Answer honestly and step into the next chapter.",
            fact="Judgement is about awakening, not punishment.",
        ),
        "ru": MajorCardLocale(
            title="Суд",
            keywords=["пробуждение", "ответ", "призвание"],
            general="Призыв подняться и взять ответственность.",
            light="Обновление, прощение и ясное предназначение.",
            shadow="Жесткая самооценка или отказ от призыва.",
            advice="Ответьте честно и войдите в новую главу.",
            fact="Суд — это пробуждение, а не наказание.",
        ),
        "kk": MajorCardLocale(
            title="Сот",
            keywords=["ояну", "есеп", "мақсат"],
            general="Тұрып, жауап беруге шақыру.",
            light="Жаңару, кешірім және айқын мақсат.",
            shadow="Қатал өзін-өзі соттау немесе шақырудан бас тарту.",
            advice="Шынайы жауап беріп, жаңа тарауға қадам басыңыз.",
            fact="Сот — жазалау емес, ояну туралы.",
        ),
    },
    "major_21_world": {
        "en": MajorCardLocale(
            title="The World",
            keywords=["completion", "wholeness", "integration"],
            general="Completion and a sense of wholeness.",
            light="Integration, reward, and earned closure.",
            shadow="Delays in finishing or fearing the next cycle.",
            advice="Honor what is complete and open the next door.",
            fact="The World closes the Major Arcana journey.",
        ),
        "ru": MajorCardLocale(
            title="Мир",
            keywords=["завершение", "целостность", "интеграция"],
            general="Завершение и чувство целостности.",
            light="Интеграция, награда и заслуженное закрытие.",
            shadow="Задержки завершения или страх нового цикла.",
            advice="Отпразднуйте завершение и откройте следующую дверь.",
            fact="Мир завершает путь Старших Арканов.",
        ),
        "kk": MajorCardLocale(
            title="Әлем",
            keywords=["аяқталу", "тұтастық", "біріктіру"],
            general="Аяқталу және тұтастық сезімі.",
            light="Біріктіру, марапат және лайықты жабылу.",
            shadow="Аяқтауды созу немесе келесі циклдан қорқу.",
            advice="Аяқталғанды бағалап, жаңа есікті ашыңыз.",
            fact="Әлем — Үлкен Арканалардың сапарын аяқтайды.",
        ),
    },
}

SUITS = ["wands", "cups", "swords", "pentacles"]

SUIT_TITLES = {
    "en": {
        "wands": "Wands",
        "cups": "Cups",
        "swords": "Swords",
        "pentacles": "Pentacles",
    },
    "ru": {
        "wands": "Жезлов",
        "cups": "Кубков",
        "swords": "Мечей",
        "pentacles": "Пентаклей",
    },
    "kk": {
        "wands": "Таяқтардың",
        "cups": "Кубоктардың",
        "swords": "Қылыштардың",
        "pentacles": "Пентакльдердің",
    },
}

SUIT_THEMES = {
    "en": {
        "wands": "passion, action, and courage",
        "cups": "emotion, connection, and intuition",
        "swords": "mind, truth, and decisions",
        "pentacles": "material life, resources, and stability",
    },
    "ru": {
        "wands": "страсть, действие и смелость",
        "cups": "чувства, связь и интуиция",
        "swords": "разум, истина и решения",
        "pentacles": "материя, ресурсы и устойчивость",
    },
    "kk": {
        "wands": "жігер, әрекет және батылдық",
        "cups": "сезім, байланыс және түйсік",
        "swords": "ақыл, ақиқат және шешім",
        "pentacles": "материалдық өмір, ресурстар және тұрақтылық",
    },
}

SUIT_KEYWORDS = {
    "en": {
        "wands": ["drive", "creativity"],
        "cups": ["emotion", "connection"],
        "swords": ["clarity", "truth"],
        "pentacles": ["stability", "resources"],
    },
    "ru": {
        "wands": ["воля", "вдохновение"],
        "cups": ["чувства", "связь"],
        "swords": ["ясность", "истина"],
        "pentacles": ["устойчивость", "ресурсы"],
    },
    "kk": {
        "wands": ["жігер", "шабыт"],
        "cups": ["сезім", "байланыс"],
        "swords": ["айқындық", "ақиқат"],
        "pentacles": ["тұрақтылық", "ресурстар"],
    },
}

RANK_TITLES = {
    "en": {
        "ace": "Ace",
        "two": "Two",
        "three": "Three",
        "four": "Four",
        "five": "Five",
        "six": "Six",
        "seven": "Seven",
        "eight": "Eight",
        "nine": "Nine",
        "ten": "Ten",
        "page": "Page",
        "knight": "Knight",
        "queen": "Queen",
        "king": "King",
    },
    "ru": {
        "ace": "Туз",
        "two": "Двойка",
        "three": "Тройка",
        "four": "Четверка",
        "five": "Пятерка",
        "six": "Шестерка",
        "seven": "Семерка",
        "eight": "Восьмерка",
        "nine": "Девятка",
        "ten": "Десятка",
        "page": "Паж",
        "knight": "Рыцарь",
        "queen": "Королева",
        "king": "Король",
    },
    "kk": {
        "ace": "Тузы",
        "two": "Екілік",
        "three": "Үштік",
        "four": "Төрттік",
        "five": "Бестік",
        "six": "Алтылық",
        "seven": "Жетілік",
        "eight": "Сегіздік",
        "nine": "Тоғыздық",
        "ten": "Ондық",
        "page": "Паж",
        "knight": "Сері",
        "queen": "Ханым",
        "king": "Патша",
    },
}

RANK_DATA = {
    "en": {
        "ace": {
            "keywords": ["spark", "potential", "beginning"],
            "general": "a new seed and raw potential",
            "light": "fresh energy and a clean opening",
            "shadow": "potential without follow-through",
            "advice": "plant the seed and nurture it",
            "fact": "Aces are the first pulse of the suit",
        },
        "two": {
            "keywords": ["choice", "balance", "planning"],
            "general": "a choice and a wider horizon",
            "light": "steady planning and clear options",
            "shadow": "indecision or waiting too long",
            "advice": "choose a direction and commit",
            "fact": "Twos weigh options before the journey",
        },
        "three": {
            "keywords": ["growth", "teamwork", "progress"],
            "general": "early results and expansion",
            "light": "collaboration and momentum",
            "shadow": "misalignment or slow feedback",
            "advice": "share the load and keep moving",
            "fact": "Threes mark growth after the first step",
        },
        "four": {
            "keywords": ["stability", "rest", "foundation"],
            "general": "stability and consolidation",
            "light": "healthy rest and grounded structure",
            "shadow": "stagnation or holding too tight",
            "advice": "stabilize without freezing",
            "fact": "Fours create a base before the next push",
        },
        "five": {
            "keywords": ["challenge", "conflict", "test"],
            "general": "friction and a test of will",
            "light": "learning through challenge",
            "shadow": "chaos, ego clashes, or loss",
            "advice": "address the tension directly",
            "fact": "Fives introduce change through tension",
        },
        "six": {
            "keywords": ["harmony", "support", "success"],
            "general": "progress and shared support",
            "light": "recognition and smooth cooperation",
            "shadow": "complacency or shallow wins",
            "advice": "accept help and keep pace",
            "fact": "Sixes bring cooperation and relief",
        },
        "seven": {
            "keywords": ["strategy", "defense", "evaluation"],
            "general": "strategy and measured resistance",
            "light": "focus, persistence, and smart boundaries",
            "shadow": "overdefending or second-guessing",
            "advice": "protect your ground without closing off",
            "fact": "Sevens test focus and resolve",
        },
        "eight": {
            "keywords": ["movement", "practice", "momentum"],
            "general": "speed and skill-building",
            "light": "productive flow and steady motion",
            "shadow": "rushed choices or burnout",
            "advice": "move quickly, but keep form",
            "fact": "Eights accelerate the suit's energy",
        },
        "nine": {
            "keywords": ["resilience", "boundaries", "near-complete"],
            "general": "endurance and nearing completion",
            "light": "strong boundaries and grit",
            "shadow": "fatigue or isolation",
            "advice": "protect your energy and finish well",
            "fact": "Nines hold steady near the finish",
        },
        "ten": {
            "keywords": ["culmination", "burden", "closure"],
            "general": "a cycle reaching full weight",
            "light": "completion and a clear finish line",
            "shadow": "overload or carrying too much",
            "advice": "share the burden and wrap it up",
            "fact": "Tens close the suit's cycle",
        },
        "page": {
            "keywords": ["curiosity", "messages", "learning"],
            "general": "curiosity and new information",
            "light": "fresh study and openness",
            "shadow": "naivety or scattered attention",
            "advice": "stay curious and grounded",
            "fact": "Pages signal messages and beginnings",
        },
        "knight": {
            "keywords": ["drive", "action", "quest"],
            "general": "decisive action and pursuit",
            "light": "bold movement and initiative",
            "shadow": "impulsiveness or recklessness",
            "advice": "act with courage and direction",
            "fact": "Knights bring motion to the suit",
        },
        "queen": {
            "keywords": ["mastery", "care", "inner strength"],
            "general": "inner mastery and steady care",
            "light": "warm leadership and emotional intelligence",
            "shadow": "overcontrol or hidden resentment",
            "advice": "lead quietly and consistently",
            "fact": "Queens hold the suit's wisdom within",
        },
        "king": {
            "keywords": ["leadership", "authority", "direction"],
            "general": "outward mastery and leadership",
            "light": "clear authority and wise direction",
            "shadow": "rigidity or misuse of power",
            "advice": "use your authority with integrity",
            "fact": "Kings express the suit's power outwardly",
        },
    },
    "ru": {
        "ace": {
            "keywords": ["импульс", "потенциал", "начало"],
            "general": "новый импульс и сырой потенциал",
            "light": "свежая энергия и чистое начало",
            "shadow": "потенциал без продолжения",
            "advice": "посейте семя и выращивайте его",
            "fact": "Тузы — первый импульс масти",
        },
        "two": {
            "keywords": ["выбор", "баланс", "план"],
            "general": "выбор и расширение горизонта",
            "light": "спокойное планирование и ясные варианты",
            "shadow": "нерешительность или ожидание",
            "advice": "выберите направление и двигайтесь",
            "fact": "Двойки взвешивают варианты перед путём",
        },
        "three": {
            "keywords": ["рост", "сотрудничество", "прогресс"],
            "general": "первые результаты и расширение",
            "light": "сотрудничество и движение",
            "shadow": "несогласованность или медленная отдача",
            "advice": "делитесь задачами и продолжайте",
            "fact": "Тройки отмечают рост после первого шага",
        },
        "four": {
            "keywords": ["стабильность", "отдых", "основа"],
            "general": "стабильность и укрепление",
            "light": "здоровый отдых и опора",
            "shadow": "застой или чрезмерный контроль",
            "advice": "укрепляйте, но не замирайте",
            "fact": "Четверки создают базу перед рывком",
        },
        "five": {
            "keywords": ["испытание", "конфликт", "напряжение"],
            "general": "трение и проверка воли",
            "light": "рост через испытание",
            "shadow": "хаос, конфликты или потери",
            "advice": "признайте напряжение и действуйте",
            "fact": "Пятерки приносят перемены через напряжение",
        },
        "six": {
            "keywords": ["гармония", "поддержка", "успех"],
            "general": "прогресс и общая поддержка",
            "light": "признание и плавное сотрудничество",
            "shadow": "самодовольство или поверхностный успех",
            "advice": "принимайте помощь и держите темп",
            "fact": "Шестерки несут поддержку и облегчение",
        },
        "seven": {
            "keywords": ["стратегия", "защита", "оценка"],
            "general": "стратегия и выверенная защита",
            "light": "фокус, стойкость и границы",
            "shadow": "чрезмерная оборона или сомнения",
            "advice": "защищайте позиции без закрытости",
            "fact": "Семерки проверяют фокус и выдержку",
        },
        "eight": {
            "keywords": ["движение", "практика", "скорость"],
            "general": "ускорение и отработка навыка",
            "light": "рабочий поток и стабильное движение",
            "shadow": "спешка или выгорание",
            "advice": "двигайтесь быстро, но качественно",
            "fact": "Восьмерки ускоряют энергию масти",
        },
        "nine": {
            "keywords": ["стойкость", "границы", "финиш"],
            "general": "выносливость и близость к завершению",
            "light": "сильные границы и стойкость",
            "shadow": "усталость или изоляция",
            "advice": "сберегайте силы и завершайте",
            "fact": "Девятки удерживают позицию у финиша",
        },
        "ten": {
            "keywords": ["кульминация", "нагрузка", "закрытие"],
            "general": "цикл, дошедший до полной нагрузки",
            "light": "завершение и ясная черта",
            "shadow": "перегрузка или взваливание всего",
            "advice": "разделите груз и завершайте",
            "fact": "Десятки закрывают цикл масти",
        },
        "page": {
            "keywords": ["любопытство", "новости", "учеба"],
            "general": "любопытство и новые новости",
            "light": "свежая учеба и открытость",
            "shadow": "наивность или рассеянность",
            "advice": "оставайтесь любопытными и собранными",
            "fact": "Пажи приносят сообщения и старт",
        },
        "knight": {
            "keywords": ["движение", "действие", "поиск"],
            "general": "решительное действие и рывок",
            "light": "смелый старт и инициатива",
            "shadow": "импульсивность или риск",
            "advice": "действуйте смело, но с целью",
            "fact": "Рыцари несут движение масти",
        },
        "queen": {
            "keywords": ["мастерство", "забота", "внутренняя сила"],
            "general": "внутреннее мастерство и устойчивую заботу",
            "light": "теплое лидерство и эмоциональный интеллект",
            "shadow": "скрытая обида или чрезмерный контроль",
            "advice": "ведите тихо и последовательно",
            "fact": "Королевы держат мудрость масти внутри",
        },
        "king": {
            "keywords": ["лидерство", "власть", "направление"],
            "general": "внешнее мастерство и лидерство",
            "light": "ясная власть и мудрый курс",
            "shadow": "жесткость или злоупотребление силой",
            "advice": "управляйте честно и твердо",
            "fact": "Короли выражают силу масти вовне",
        },
    },
    "kk": {
        "ace": {
            "keywords": ["серпін", "әлеует", "бастау"],
            "general": "жаңа серпін мен бастапқы әлеует",
            "light": "жаңа қуат пен таза бастау",
            "shadow": "әлеуеттің іске аспауы",
            "advice": "тұқымды егіп, оны күтіңіз",
            "fact": "Туздар — мастьтың алғашқы серпіні",
        },
        "two": {
            "keywords": ["таңдау", "теңдік", "жоспар"],
            "general": "таңдау және көкжиекті кеңейту",
            "light": "сабырлы жоспар және айқын нұсқалар",
            "shadow": "шешімсіздік немесе ұзақ кідіру",
            "advice": "бағытты таңдап, ұстаныңыз",
            "fact": "Екіліктер сапар алдында нұсқаларды өлшейді",
        },
        "three": {
            "keywords": ["өсу", "әріптестік", "прогресс"],
            "general": "алғашқы нәтиже және кеңею",
            "light": "бірлесу және серпін",
            "shadow": "үйлеспеу немесе баяу қайтарым",
            "advice": "жүктемені бөлісіп, ілгерілеңіз",
            "fact": "Үштіктер алғашқы қадамнан кейінгі өсуді білдіреді",
        },
        "four": {
            "keywords": ["тұрақтылық", "тынығу", "негіз"],
            "general": "тұрақтылық пен нығаю",
            "light": "сау тынығу және берік негіз",
            "shadow": "тоқырау немесе тым ұстап қалу",
            "advice": "тұрақтаңыз, бірақ қатып қалмаңыз",
            "fact": "Төрттіктер келесі серпінге дейін негіз құрады",
        },
        "five": {
            "keywords": ["сынақ", "қайшылық", "кернеу"],
            "general": "үйкеліс пен ерікті сынау",
            "light": "сын арқылы үйрену",
            "shadow": "хаос, қақтығыс немесе жоғалту",
            "advice": "кернеуді мойындап, әрекет етіңіз",
            "fact": "Бестіктер өзгерісті кернеу арқылы әкеледі",
        },
        "six": {
            "keywords": ["үйлесім", "қолдау", "табыс"],
            "general": "ілгерілеу және ортақ қолдау",
            "light": "мойындау және жеңіл әріптестік",
            "shadow": "өз-өзіне риза болу немесе үстірт жеңіс",
            "advice": "көмекті қабылдап, қарқынды ұстаңыз",
            "fact": "Алтылықтар қолдау мен жеңілдікті алып келеді",
        },
        "seven": {
            "keywords": ["стратегия", "қорғаныс", "бағалау"],
            "general": "стратегия және өлшенген қорғаныс",
            "light": "назар, төзім және шекара",
            "shadow": "артық қорғану немесе күмән",
            "advice": "шекараны сақтап, бірақ жабылып қалмаңыз",
            "fact": "Жетіліктер назар мен төзімділікті сынайды",
        },
        "eight": {
            "keywords": ["қозғалыс", "жаттығу", "серпін"],
            "general": "жылдамдық және дағдыны жетілдіру",
            "light": "өнімді ағым және тұрақты қозғалыс",
            "shadow": "асығыстық немесе күйіп кету",
            "advice": "жылдам жүріп, сапаны сақтаңыз",
            "fact": "Сегіздіктер масть қуатын үдетеді",
        },
        "nine": {
            "keywords": ["төзім", "шекара", "аяқталу"],
            "general": "төзімділік және мәреге жақындау",
            "light": "берік шекара және төзім",
            "shadow": "шаршау немесе оқшаулану",
            "advice": "қуатты сақтап, аяғына жеткізіңіз",
            "fact": "Тоғыздықтар мәреге жақын кезде ұстап тұрады",
        },
        "ten": {
            "keywords": ["шарықтау", "жүк", "жабылу"],
            "general": "циклдың толық салмаққа жетуі",
            "light": "аяқталу және айқын шек",
            "shadow": "артық жүк немесе бәрін өзіне алу",
            "advice": "жүктемені бөлісіп, аяқтаңыз",
            "fact": "Ондықтар масть циклын жабады",
        },
        "page": {
            "keywords": ["қызығушылық", "хабар", "үйрену"],
            "general": "қызығушылық және жаңа хабар",
            "light": "жаңа оқу және ашықтық",
            "shadow": "аңғалдық немесе шашыраңқылық",
            "advice": "қызығушылықты сақтап, жинақы болыңыз",
            "fact": "Паждар хабар мен бастаманы әкеледі",
        },
        "knight": {
            "keywords": ["қозғалыс", "әрекет", "ізденіс"],
            "general": "шешімді әрекет және ұмтылыс",
            "light": "батыл қадам және бастама",
            "shadow": "импульсивтілік немесе асығыстық",
            "advice": "мақсатпен батыл қимылдаңыз",
            "fact": "Серілер мастьқа қозғалыс әкеледі",
        },
        "queen": {
            "keywords": ["шеберлік", "қамқорлық", "ішкі күш"],
            "general": "ішкі шеберлік пен тұрақты қамқорлық",
            "light": "жылы басшылық және эмоциялық зерде",
            "shadow": "жасырын реніш немесе артық бақылау",
            "advice": "тым қатты емес, сабырмен басқарыңыз",
            "fact": "Ханымдар масть даналығын ішінде ұстайды",
        },
        "king": {
            "keywords": ["басшылық", "билік", "бағыт"],
            "general": "сыртқы шеберлік пен басшылық",
            "light": "айқын билік және дана бағыт",
            "shadow": "қаттылық немесе күшті теріс қолдану",
            "advice": "әділдікпен басқарыңыз",
            "fact": "Патшалар масть күшін сыртқа шығарады",
        },
    },
}

RANK_ORDER = [
    "knight",
    "king",
    "queen",
    "page",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "ace",
]

RANK_STATS = {
    "ace": {"luck": 4, "power": 10, "love": 2, "clarity": 6},
    "two": {"luck": 2, "power": 0, "love": 4, "clarity": 6},
    "three": {"luck": 4, "power": 2, "love": 6, "clarity": 2},
    "four": {"luck": 0, "power": 2, "love": 2, "clarity": 6},
    "five": {"luck": -6, "power": 2, "love": -2, "clarity": 0},
    "six": {"luck": 6, "power": 2, "love": 4, "clarity": 2},
    "seven": {"luck": -2, "power": 4, "love": 0, "clarity": 4},
    "eight": {"luck": 2, "power": 4, "love": 0, "clarity": 6},
    "nine": {"luck": 0, "power": 2, "love": 6, "clarity": 2},
    "ten": {"luck": -2, "power": -2, "love": 2, "clarity": 4},
    "page": {"luck": 4, "power": 2, "love": 2, "clarity": 2},
    "knight": {"luck": 2, "power": 8, "love": 0, "clarity": 2},
    "queen": {"luck": 2, "power": 2, "love": 8, "clarity": 2},
    "king": {"luck": 2, "power": 8, "love": 2, "clarity": 6},
}

SUIT_STATS = {
    "wands": {"luck": 2, "power": 8, "love": 0, "clarity": 2},
    "cups": {"luck": 4, "power": 0, "love": 8, "clarity": 2},
    "swords": {"luck": 0, "power": 4, "love": 0, "clarity": 8},
    "pentacles": {"luck": 8, "power": 2, "love": 0, "clarity": 4},
}


def clamp(value: int, minimum: int = 10, maximum: int = 95) -> int:
    return max(min(value, maximum), minimum)


def build_stats(rank: str, suit: str) -> dict[str, int]:
    base = {"luck": 50, "power": 50, "love": 50, "clarity": 50}
    for key, delta in SUIT_STATS[suit].items():
        base[key] += delta
    for key, delta in RANK_STATS[rank].items():
        base[key] += delta
    return {key: clamp(value) for key, value in base.items()}


def build_detailed(general: str, light: str, shadow: str, advice: str) -> str:
    return " ".join(
        part.rstrip(".") + "."
        for part in [general, light, shadow, advice]
        if part
    )


def title_for_minor(locale: str, rank: str, suit: str) -> str:
    rank_title = RANK_TITLES[locale][rank]
    suit_title = SUIT_TITLES[locale][suit]
    if locale == "en":
        return f"{rank_title} of {suit_title}"
    if locale == "kk":
        return f"{suit_title} {rank_title}"
    return f"{rank_title} {suit_title}"


def build_minor_entry(locale: str, rank: str, suit: str) -> dict[str, object]:
    rank_data = RANK_DATA[locale][rank]
    rank_title = RANK_TITLES[locale][rank]
    suit_title = SUIT_TITLES[locale][suit]
    theme = SUIT_THEMES[locale][suit]

    if locale == "en":
        general = (
            f"The {rank_title} of {suit_title} points to {rank_data['general']} in the realm of {theme}."
        )
        light = f"At its best, it shows {rank_data['light']}."
        shadow = f"In shadow, it can show {rank_data['shadow']}."
        advice = f"Advice: {rank_data['advice']}."
        fact = f"{rank_data['fact']} in {suit_title}."
    elif locale == "ru":
        general = (
            f"{rank_title} {suit_title} говорит про {rank_data['general']} в теме: {theme}."
        )
        light = f"В светлой стороне это {rank_data['light']}."
        shadow = f"В тени проявляется {rank_data['shadow']}."
        advice = f"Совет: {rank_data['advice']}."
        fact = f"{rank_data['fact']} в масти {suit_title}."
    else:
        general = (
            f"{rank_title} {suit_title} — {rank_data['general']} тақырыбы: {theme}."
        )
        light = f"Жарық қырында бұл {rank_data['light']}."
        shadow = f"Көлеңкеде {rank_data['shadow']} байқалады."
        advice = f"Кеңес: {rank_data['advice']}."
        fact = f"{rank_data['fact']} {suit_title} мастында."

    keywords = [
        *rank_data["keywords"],
        *SUIT_KEYWORDS[locale][suit],
    ]

    return {
        "title": title_for_minor(locale, rank, suit),
        "keywords": keywords,
        "meaning": {
            "general": general,
            "light": light,
            "shadow": shadow,
            "advice": advice,
        },
        "fact": fact,
        "stats": build_stats(rank, suit),
        "detailedDescription": build_detailed(general, light, shadow, advice),
    }


def build_major_entry(locale: str, card_id: str) -> dict[str, object]:
    card = MAJOR_CARDS[card_id][locale]
    return {
        "title": card.title,
        "keywords": card.keywords,
        "meaning": {
            "general": card.general,
            "light": card.light,
            "shadow": card.shadow,
            "advice": card.advice,
        },
        "fact": card.fact,
        "stats": {
            "luck": 50,
            "power": 55,
            "love": 50,
            "clarity": 55,
        },
        "detailedDescription": build_detailed(
            card.general, card.light, card.shadow, card.advice
        ),
    }


def load_card_order() -> list[str]:
    with (CDN_DATA_DIR / "cards_en.json").open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    return list(data.keys())


def write_locale(locale: str, card_order: list[str]) -> None:
    output: "OrderedDict[str, dict[str, object]]" = OrderedDict()
    for card_id in card_order:
        if card_id.startswith("major_"):
            output[card_id] = build_major_entry(locale, card_id)
            continue

        suit, _, rank = card_id.split("_", 2)
        output[card_id] = build_minor_entry(locale, rank, suit)

    file_locale = LOCALE_FILE_MAP[locale]
    for directory in (CDN_DATA_DIR, APP_DATA_DIR):
        path = directory / f"cards_{file_locale}.json"
        with path.open("w", encoding="utf-8") as handle:
            json.dump(output, handle, ensure_ascii=False, indent=2)
            handle.write("\n")


def main() -> None:
    card_order = load_card_order()
    for locale in ("en", "ru", "kk"):
        write_locale(locale, card_order)


if __name__ == "__main__":
    main()
