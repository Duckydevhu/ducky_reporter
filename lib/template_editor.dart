import 'dart:io'; // A fájlok másolásához és a JSON mentéséhez.
import 'package:flutter/material.dart'; // A UI elemekhez (Ablakok, Gombok, Listák).
import 'package:file_selector/file_selector.dart'; // A Google hivatalos, biztonságos fájltallózója.
import 'models.dart'; // Az adatmodelljeink (TemplateField, ReportTemplate).
import 'file_manager.dart'; // A mappák (Templates) eléréséhez.

// ==========================================
// SABLONSZERKESZTŐ KÉPERNYŐ
// ==========================================
/// Ez a felület felelős azért, hogy a felhasználó feltölthessen egy üres Word dokumentumot,
/// elnevezze azt, és felvegyen hozzá tetszőleges számú dinamikus mezőt.
class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  // A sablon nevének beviteléhez (pl. "Havi_Jelentes")
  final TextEditingController _nameController = TextEditingController();
  
  // Itt tároljuk a betallózott eredeti DOCX fájl pontos útvonalát
  String? _selectedDocxPath;
  
  // Egy üres lista, amibe a felugró ablakból adjuk hozzá az új mezőket
  final List<TemplateField> _fields = [];

  // ==========================================
  // 1. DOCX FÁJL TALLÓZÁSA
  // ==========================================
  /// Megnyitja a telefon beépített fájlkezelőjét, és csak a .docx kiterjesztést engedi kiválasztani
  Future<void> _pickDocx() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Word dokumentumok',
      extensions: <String>['docx'],
    );
    
    // Várjuk, hogy a felhasználó válasszon egy fájlt
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (file != null) {
      // Ha választott, elmentjük az útvonalát, és frissítjük a UI-t, hogy kiírja a nevét
      setState(() {
        _selectedDocxPath = file.path;
      });
    }
  }

  // ==========================================
  // 2. ÚJ MEZŐ HOZZÁADÁSA (FELUGRÓ ABLAK)
  // ==========================================
  /// Ez a metódus egy felugró (Dialog) ablakot nyit meg, ahol a felhasználó definiálhat egy kérdést az űrlaphoz
  void _addFieldDialog() {
    // A felugró ablak belső "memóriája" (Alapból szöveg típusú mezővel indulunk)
    String selectedType = 'text';
    final TextEditingController fieldNameCtrl = TextEditingController();
    final TextEditingController optionsCtrl = TextEditingController();
    bool isRequired = false;
    
    showDialog(
      context: context,
      builder: (context) {
        // FONTOS TRÜKK: A showDialog egy különálló "sziget" a képernyőn.
        // Hogy a felugró ablakon belül működjön a legördülő menü és a checkbox frissítése,
        // kell egy 'StatefulBuilder', ami ad nekünk egy saját 'setDialogState' frissítő függvényt.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Új mező hozzáadása'),
              // SingleChildScrollView kell, hogy ne lógjon ki a képernyőről, ha feljön a billentyűzet
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A Mező Neve (pl. <<UgyfelNeve>>)
                    TextField(
                      controller: fieldNameCtrl,
                      decoration: const InputDecoration(labelText: 'Mező neve (pl. UgyfelNeve)'),
                    ),
                    const SizedBox(height: 15),
                    
                    // A Mező Típusa (Szöveg, Dátum, Legördülő, Checkbox)
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Mező típusa'),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text('Szöveg (Multiline)')),
                        DropdownMenuItem(value: 'date', child: Text('Dátum')),
                        DropdownMenuItem(value: 'dropdown', child: Text('Legördülő lista')),
                        DropdownMenuItem(value: 'checkbox', child: Text('Jelölőnégyzet (Checkbox)')),
                      ],
                      onChanged: (val) {
                        // Itt használjuk a belső setDialogState-et a normál setState helyett!
                        setDialogState(() {
                          selectedType = val!;
                        });
                      },
                    ),
                    
                    // CSINOSÍTÁS: Csak akkor kérjük be az "Opciókat", ha a típus "dropdown"
                    if (selectedType == 'dropdown') ...[
                      const SizedBox(height: 15),
                      TextField(
                        controller: optionsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Opciók pontosvesszővel elválasztva',
                          hintText: 'Igen;Nem;Talán', // Segítség a felhasználónak
                        ),
                      ),
                    ],
                    const SizedBox(height: 15),
                    
                    // Kötelező-e kitölteni a riportkészítésnél?
                    CheckboxListTile(
                      title: const Text('Kötelező kitölteni?'),
                      value: isRequired,
                      onChanged: (val) {
                        setDialogState(() {
                          isRequired = val ?? false;
                        });
                      },
                    )
                  ],
                ),
              ),
              actions: [
                // Visszalépés (Mégse)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Mégse'),
                ),
                // Mező véglegesítése (Hozzáadás)
                ElevatedButton(
                  onPressed: () {
                    // Nem engedjük menteni, ha nincs neve
                    if (fieldNameCtrl.text.isEmpty) return;
                    
                    // Létrehozzuk az új TemplateField objektumot
                    final newField = TemplateField(
                      name: fieldNameCtrl.text,
                      type: selectedType,
                      isRequired: isRequired,
                      // Ha legördülő listát kért, a pontosvesszőknél szétszedjük egy Dart listává
                      dropdownOptions: selectedType == 'dropdown' 
                          ? optionsCtrl.text.split(';').map((e) => e.trim()).toList() 
                          : [],
                    );
                    
                    // Frissítjük a *főképernyőt*, hogy bekerüljön a listába az új kártya
                    setState(() {
                      _fields.add(newField);
                    });
                    
                    // Bezárjuk a felugró ablakot
                    Navigator.pop(context);
                  },
                  child: const Text('Hozzáadás'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 3. A KÉSZ SABLON MENTÉSE
  // ==========================================
  /// Ellenőrzi, hogy mindent megadtak-e, átmásolja a DOCX-et a munkamappába, és kimenti a JSON tervrajzot
  Future<void> _saveTemplate() async {
    // Validáció: Ha hiányzik valami, piros hibát dobunk
    if (_nameController.text.isEmpty || _selectedDocxPath == null || _fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adj meg egy nevet, tallózz be egy DOCX-et, és vegyél fel legalább egy mezőt!'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final templatesDir = await FileManager.getTemplatesPath();
      
      // 1. ÁTMÁSOLJUK A DOCX FÁJLT
      // Ezzel biztosítjuk, hogy ha a felhasználó letörli a telefon Letöltések mappájából az eredetit,
      // a Ducky Reporter saját mappájában még meglesz a biztonsági másolat.
      final originalFile = File(_selectedDocxPath!);
      final docxFileName = _selectedDocxPath!.split(Platform.pathSeparator).last; // Eredeti fájlnév kinyerése
      final newDocxPath = '$templatesDir/$docxFileName';
      await originalFile.copy(newDocxPath);
      
      // 2. JSON ADATMODELL FELÉPÍTÉSE
      final template = ReportTemplate(
        templateName: _nameController.text,
        docxPath: newDocxPath, // Már az átmásolt (új) útvonalra hivatkozunk!
        fields: _fields,
      );
      
      // 3. JSON FÁJL MENTÉSE A HÁTTÉRTÁRRA
      final jsonFile = File('$templatesDir/${_nameController.text}.json');
      await jsonFile.writeAsString(template.toJson());
      
      // Sikeres mentés jelzése és visszanavigálás
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sablon sikeresen elmentve!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Visszalépés a főképernyőre
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a mentéskor: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==========================================
  // KÉPERNYŐ FELÉPÍTÉSE (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Új Sablon Készítése'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Fenti Mentés gomb
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Mentés',
            onPressed: _saveTemplate,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sablon Neve mező
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Sablon neve (pl: Havi_Jelentes)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            // DOCX BETALLÓZÓ SZEKCIÓ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    // Ha van betallózott fájl, kiírjuk az útvonalát, különben a hibaüzenetet
                    child: Text(
                      _selectedDocxPath ?? 'Nincs DOCX fájl kiválasztva!',
                      style: TextStyle(
                        color: _selectedDocxPath == null ? Colors.red : Colors.black87,
                      ),
                      // ellipsis: Ha túl hosszú az útvonal, a végét kipontozza ("...") ahelyett, hogy szétcsúszna a UI
                      overflow: TextOverflow.ellipsis, 
                    ),
                  ),
                  // A DOCX Tallózó Gomb
                  ElevatedButton.icon(
                    onPressed: _pickDocx,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('DOCX Tallózása'),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('Dinamikus mezők:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // FELVETT MEZŐK LISTÁJA
            // Az 'Expanded' gondoskodik róla, hogy ez a lista töltse ki a maradék üres helyet lefelé.
            Expanded(
              child: _fields.isEmpty
                  ? const Center(child: Text('Még nem adtál hozzá mezőket.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _fields.length,
                      itemBuilder: (context, index) {
                        final field = _fields[index]; // Az aktuális mező
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              // A mező típusától függően cserélgetjük a bal oldali ikont (vizuális extra)
                              child: Icon(
                                field.type == 'text' ? Icons.text_fields :
                                field.type == 'date' ? Icons.calendar_today :
                                field.type == 'checkbox' ? Icons.check_box :
                                Icons.arrow_drop_down_circle
                              ),
                            ),
                            title: Text(field.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            // Kiírjuk a típusát és hogy kötelező-e
                            subtitle: Text('Típus: ${field.type} | Kötelező: ${field.isRequired ? "Igen" : "Nem"}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red), // Törlés (kuka) ikon
                              onPressed: () {
                                // Ha a kukára nyomnak, egyszerűen kivesszük a memóriából a mezőt
                                setState(() {
                                  _fields.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // A lebegő kerek gomb a jobb alsó sarokban, ami a felugró ablakot nyitja
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFieldDialog,
        icon: const Icon(Icons.add),
        label: const Text('Mező Hozzáadása'),
      ),
    );
  }
}