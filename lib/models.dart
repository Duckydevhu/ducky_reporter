import 'dart:convert'; // Ez a csomag felelős a json.encode (becsomagolás) és json.decode (kicsomagolás) műveletekért.

// ==========================================
// 1. EGYETLEN MEZŐ (FIELD) DEFINÍCIÓJA
// ==========================================
/// Ez az osztály írja le, hogy hogyan néz ki egyetlen "kérdés" vagy "mező" a sablonodban.
/// Amikor a Sablonszerkesztőben hozzáadsz egy új mezőt, valójában egy ilyen objektumot hozol létre.
class TemplateField {
  String name; // A mező neve (pl. "UgyfelNeve"). Ezt fogjuk keresni a DOCX-ben (<<UgyfelNeve>>).
  String type; // A mező típusa a felületen: 'text', 'date', 'dropdown' vagy 'checkbox'.
  List<String> dropdownOptions; // Ha a típus 'dropdown', itt tároljuk a választható opciókat egy listában.
  String defaultValue; // Az alapértelmezett érték, ha a felhasználó nem ír be semmit.
  bool isRequired; // Kötelező-e kitölteni ezt a mezőt (true/false).

  // A konstruktor (építő), amivel létrehozunk egy új mezőt.
  // A 'required' azt jelenti, hogy név és típus nélkül nem is engedi létrehozni.
  TemplateField({
    required this.name,
    required this.type,
    this.dropdownOptions = const [],
    this.defaultValue = '',
    this.isRequired = false,
  });

  // ----------------------------------------------------
  // JSON MENTÉS ÉS BETÖLTÉS LOGIKÁJA (Szerializáció)
  // ----------------------------------------------------

  /// Amikor a Dart objektumot el akarjuk menteni, először át kell alakítanunk egy 
  /// Map-pé (Kulcs-Érték párokká), amit a JSON konverter már megért.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'dropdownOptions': dropdownOptions,
      'defaultValue': defaultValue,
      'isRequired': isRequired,
    };
  }

  /// Ez egy "Gyár" (factory), ami a beolvasott fájlból (JSON -> Map) 
  /// újra felépít egy igazi Dart objektumot a memóriában.
  /// A `??` operátorok arra jók, hogy ha egy adat véletlenül hiányozna a fájlból, 
  /// akkor ne omoljon össze az app, hanem adjon egy alapértéket (pl. üres szöveget '').
  factory TemplateField.fromMap(Map<String, dynamic> map) {
    return TemplateField(
      name: map['name'] ?? '',
      type: map['type'] ?? 'text',
      dropdownOptions: List<String>.from(map['dropdownOptions'] ?? []),
      defaultValue: map['defaultValue'] ?? '',
      isRequired: map['isRequired'] ?? false,
    );
  }
}

// ==========================================
// 2. A TEMPLATE (SABLON) STRUKTÚRÁJA
// ==========================================
/// Ez az osztály képvisel egy teljes, elmentett Sablont.
/// Ez köti össze a fizikai .docx fájlt a benne lévő, általunk definiált mezőkkel.
class ReportTemplate {
  String templateName; // A sablon neve (pl. "Munkalap_Sablon"). Ezen a néven lesz elmentve a JSON is.
  String docxPath; // Hivatkozás a háttértáron lévő, üres Word dokumentumra.
  List<TemplateField> fields; // Egy lista, ami tartalmazza a sablonhoz tartozó összes mezőt.

  ReportTemplate({
    required this.templateName,
    required this.docxPath,
    required this.fields,
  });

  /// Dart objektum -> Kulcs-Érték (Map)
  Map<String, dynamic> toMap() {
    return {
      'templateName': templateName,
      'docxPath': docxPath,
      // Végigmegyünk a mezők listáján, és minden egyes TemplateField-nek meghívjuk a toMap() függvényét is!
      'fields': fields.map((x) => x.toMap()).toList(),
    };
  }

  /// Kulcs-Érték (Map) -> Dart objektum
  factory ReportTemplate.fromMap(Map<String, dynamic> map) {
    return ReportTemplate(
      templateName: map['templateName'] ?? '',
      docxPath: map['docxPath'] ?? '',
      // Visszafejtjük a listát: minden elemből újra TemplateField objektumot csinálunk.
      fields: List<TemplateField>.from(
          (map['fields'] ?? []).map((x) => TemplateField.fromMap(x))),
    );
  }

  /// Ez a két metódus csinálja meg a végső lépést: a Map-et átalakítja hosszú stringgé (szöveggé),
  /// és vissza. Ezt a stringet írjuk bele a valós .json fájlba a telefon tárhelyén.
  String toJson() => json.encode(toMap());
  factory ReportTemplate.fromJson(String source) =>
      ReportTemplate.fromMap(json.decode(source));
}

// ==========================================
// 3. A KITÖLTÖTT RIPORT ADATHALMAZA
// ==========================================
/// Ez az osztály tárolja a felhasználó által már kitöltött, kész űrlap adatait.
/// Fontos: Ez még NEM a DOCX fájl, csak a nyers adatok elmentve, amiből bármikor 
/// újra lehet generálni a Word dokumentumot.
class ReportData {
  String reportName; // A kitöltött fájl egyedi neve (pl. TemplateNeve_2026.06.23_195740.json).
  String templateName; // Hivatkozás arra a "Szülő" sablonra, amiből ezt kiállították.
  String date; // A kitöltés dátuma a listában való megjelenítéshez.
  
  // A legfontosabb rész: Egy kulcs-érték "szótár", ami a válaszokat tárolja.
  // Példa: { "UgyfelNeve": "Kovács János", "Elvegezve": true, "AlairasDatum": "2026.06.23" }
  Map<String, dynamic> answers; 

  ReportData({
    required this.reportName,
    required this.templateName,
    required this.date,
    required this.answers,
  });

  /// Dart objektum -> Kulcs-Érték (Map)
  Map<String, dynamic> toMap() {
    return {
      'reportName': reportName,
      'templateName': templateName,
      'date': date,
      'answers': answers,
    };
  }

  /// Kulcs-Érték (Map) -> Dart objektum
  factory ReportData.fromMap(Map<String, dynamic> map) {
    return ReportData(
      reportName: map['reportName'] ?? '',
      templateName: map['templateName'] ?? '',
      date: map['date'] ?? '',
      // A válaszokat tartalmazó Map-et egy az egyben átemeljük
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
    );
  }

  /// A json encode/decode itt is a tényleges fájlba íráshoz/olvasáshoz kell.
  String toJson() => json.encode(toMap());
  factory ReportData.fromJson(String source) =>
      ReportData.fromMap(json.decode(source));
}