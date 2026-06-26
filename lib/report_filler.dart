import 'dart:io'; // A fájlok fizikai elmentéséhez (írásához) a tárhelyre.
import 'package:flutter/material.dart'; // A Flutter UI elemekhez (gombok, szövegmezők, űrlapok).
import 'package:intl/intl.dart'; // Dátumok formázásához (hogy szép "ÉÉÉÉ.MM.NN" formátumot kapjunk).
import 'models.dart'; // Az adatmodelljeinkhez (ReportTemplate, ReportData, TemplateField).
import 'file_manager.dart'; // Az útvonalkezelőnkhöz (hogy tudjuk, hol a Reports mappa).

// ==========================================
// ADATKITÖLTŐ KÉPERNYŐ (ŰRLAP)
// ==========================================
/// Ez a képernyő (StatefulWidget) felelős a riportok kitöltéséért.
/// Létrehozásakor kötelezően vár egy [ReportTemplate] objektumot (ez az a sablon, amire rányomtunk a listában).
class ReportFillerScreen extends StatefulWidget {
  final ReportTemplate template;

  const ReportFillerScreen({super.key, required this.template});

  @override
  State<ReportFillerScreen> createState() => _ReportFillerScreenState();
}

class _ReportFillerScreenState extends State<ReportFillerScreen> {
  // Egy "Mesterkulcs" az űrlaphoz (Form). Ezzel tudjuk később egyetlen paranccsal 
  // leellenőrizni (validálni) az összes mezőt, és elmenteni az adataikat.
  final _formKey = GlobalKey<FormState>();
  
  // Egy üres szótár (Map), amibe a felhasználó válaszait fogjuk gyűjteni.
  // A kulcs a mező neve lesz (pl. "UgyfelNeve"), az érték pedig a beírt szöveg vagy logikai (true/false) érték.
  final Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    // Amikor a képernyő betölt, végigmegyünk a sablon összes mezőjén, és feltöltjük 
    // az _answers szótárat az alapértelmezett (default) értékekkel.
    for (var field in widget.template.fields) {
      if (field.type == 'checkbox') {
        // A checkboxnál a 'true' / 'false' szöveget igazi logikai értékké (boolean) alakítjuk
        _answers[field.name] = field.defaultValue.toLowerCase() == 'true';
      } else {
        // Minden másnál (szöveg, dátum, lista) simán betesszük a szöveget (vagy az üres stringet)
        _answers[field.name] = field.defaultValue;
      }
    }
  }

  // ==========================================
  // DÁTUMVÁLASZTÓ LOGIKA
  // ==========================================
  /// Megnyitja a beépített Androidos naptárat, és a kiválasztott dátumot beírja a megfelelő mezőbe.
  Future<void> _pickDate(String fieldName) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // Mai nappal indul
      firstDate: DateTime(2000), // Mettől
      lastDate: DateTime(2100), // Meddig lehessen visszatekerni
    );
    
    // Ha a felhasználó nem a "Mégse" gombra nyomott, hanem tényleg választott dátumot:
    if (picked != null) {
      setState(() {
        // Az 'intl' csomag segítségével szépen megformázzuk (Pl: 2026.06.26.)
        _answers[fieldName] = DateFormat('yyyy.MM.dd.').format(picked);
      });
    }
  }

  // ==========================================
  // RIPORT MENTÉSE (JSON-BE)
  // ==========================================
  /// Ez fut le, amikor rányomnak az alul lévő "Riport Mentése" gombra.
  Future<void> _saveReport() async {
    // 1. Ellenőrizzük, hogy minden kötelező mező ki van-e töltve
    if (_formKey.currentState!.validate()) {
      // 2. Ha minden hibátlan, véglegesítjük a beírt adatokat az _answers Map-be
      _formKey.currentState!.save();

      try {
        // Megkeressük a mentési célmappát
        final reportsDir = await FileManager.getReportsPath();
        
        // Fájlnév generálása a jelenlegi időpont alapján (így sosem lesz két egyforma nevű fájl)
        // Példa kimenet: Munkalap_2026.06.26_195039
        final now = DateTime.now();
        final dateStr = DateFormat('yyyy.MM.dd_HHmmss').format(now);
        final reportFileName = '${widget.template.templateName}_$dateStr';

        // Létrehozzuk a ReportData objektumot a begyűjtött adatokból
        final reportData = ReportData(
          reportName: reportFileName,
          templateName: widget.template.templateName,
          date: DateFormat('yyyy.MM.dd.').format(now),
          answers: _answers,
        );

        // Kimentjük az egészet egy JSON fájlba a telefonra
        final jsonFile = File('$reportsDir/$reportFileName.json');
        await jsonFile.writeAsString(reportData.toJson());

        // Sikeres mentés esetén szólunk a felhasználónak, és kilépünk a képernyőről
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Riport sikeresen elmentve!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Visszalépés az előző (Sablonok) képernyőre
        }
      } catch (e) {
        // Hibakezelés (pl. ha betelt a tárhely)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hiba a mentéskor: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ==========================================
  // DINAMIKUS MEZŐ-GENERÁTOR (UI MAGIA)
  // ==========================================
  /// Ez a függvény kap egy TemplateField "tervrajzot", és visszaad egy ahhoz illő 
  /// Flutter vizuális elemet (szövegdobozt, naptárat, stb.).
  Widget _buildFieldWidget(TemplateField field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A mező neve (kivéve a checkboxnál, mert annak saját címe van).
          // Ha kötelező (isRequired), teszünk egy piros csillagot a neve végére.
          if (field.type != 'checkbox')
            Text(
              '${field.name}${field.isRequired ? " *" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          const SizedBox(height: 5),
          
          // 1. TÍPUS: SZÖVEGMEZŐ (Text)
          if (field.type == 'text')
            TextFormField(
              initialValue: _answers[field.name], // Ha volt alapértelmezett érték, beírjuk
              maxLines: null, // A 'null' engedi, hogy a szövegdoboz korlátlanul lefelé táguljon gépeléskor (Multiline)
              decoration: const InputDecoration(border: OutlineInputBorder()),
              // Validátor: Ha kötelező, de üresen hagyták, kiabálunk a felhasználóval
              validator: (val) => field.isRequired && (val == null || val.isEmpty) ? 'Kötelező mező' : null,
              onSaved: (val) => _answers[field.name] = val,
              onChanged: (val) => _answers[field.name] = val,
            ),
            
          // 2. TÍPUS: DÁTUMVÁLASZTÓ (Date)
          if (field.type == 'date')
            // Az InkWell egy kattintható területet csinál abból, ami benne van
            InkWell(
              onTap: () => _pickDate(field.name),
              child: InputDecorator(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: field.isRequired && (_answers[field.name] == null || _answers[field.name].isEmpty) ? 'Kötelező mező' : null,
                ),
                // Vagy kiírjuk a kiválasztott dátumot, vagy egy segítő szöveget
                child: Text(_answers[field.name] == null || _answers[field.name].isEmpty ? 'Válassz dátumot...' : _answers[field.name]),
              ),
            ),
            
          // 3. TÍPUS: LEGÖRDÜLŐ LISTA (Dropdown)
          if (field.type == 'dropdown')
            DropdownButtonFormField<String>(
              // Csak akkor adunk neki értéket, ha az benne van az opciók között (nem üres)
              value: _answers[field.name]?.isEmpty ?? true ? null : _answers[field.name],
              decoration: const InputDecoration(border: OutlineInputBorder()),
              // A pontosvesszővel elválasztott stringekből igazi lenyíló gombokat (DropdownMenuItem) csinálunk
              items: field.dropdownOptions.map((opt) {
                return DropdownMenuItem(value: opt, child: Text(opt));
              }).toList(),
              validator: (val) => field.isRequired && val == null ? 'Kötelező kiválasztani' : null,
              onChanged: (val) {
                // Amikor választanak valamit a listából, azonnal frissítjük a UI-t és az adatbázist
                setState(() {
                  _answers[field.name] = val;
                });
              },
            ),
            
          // 4. TÍPUS: JELÖLŐNÉGYZET (Checkbox)
          if (field.type == 'checkbox')
            CheckboxListTile(
              title: Text('${field.name}${field.isRequired ? " *" : ""}'),
              value: _answers[field.name] ?? false,
              contentPadding: EdgeInsets.zero, // Eltüntetjük a felesleges belső üres teret
              controlAffinity: ListTileControlAffinity.leading, // A kis négyzet bal oldalon legyen, ne jobb szélen
              onChanged: (val) {
                setState(() {
                  _answers[field.name] = val;
                });
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // A KÉPERNYŐ VIZUÁLIS FELÉPÍTÉSE
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // A fejlécbe beírjuk, hogy épp melyik sablont töltjük ki
        title: Text('${widget.template.templateName} Kitöltése'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Ide adjuk át a "Mesterkulcsot" az ellenőrzéshez
          child: ListView(
            children: [
              // A spread operátor (...) segítségével fogjuk a sablon mezőit, 
              // mindegyiket átküldjük a generátornak (_buildFieldWidget),
              // és az elkészült UI elemeket egyszerűen "beporlasztjuk" a listába.
              ...widget.template.fields.map((field) => _buildFieldWidget(field)),
              
              const SizedBox(height: 30), // Kis hely a gomb felett
              
              // A Mentés gomb
              ElevatedButton.icon(
                onPressed: _saveReport,
                icon: const Icon(Icons.save),
                label: const Text('Riport Mentése', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}