import 'dart:io'; // Fájlrendszer műveletekhez (pl. fájlok listázása, olvasása, törlése).
import 'package:flutter/material.dart'; // A Flutter alapvető vizuális építőkövei (Material Design).
import 'package:permission_handler/permission_handler.dart'; // Android tárhely-engedélyek kéréséhez.
import 'file_manager.dart'; // A saját útvonal-kezelőnk (Templates, Reports, Exports mappák).
import 'template_editor.dart'; // A képernyő, ahol az új DOCX sablonokat vesszük fel.
import 'models.dart'; // Az adatmodelljeink (ReportTemplate, ReportData, TemplateField).
import 'report_filler.dart'; // A képernyő, ahol a felhasználó kitölti az űrlapot.
import 'docx_engine.dart'; // A saját "fekete mágiánk", ami a DOCX (ZIP/XML) cseréket csinálja.

// ==========================================
// ALKALMAZÁS BELÉPÉSI PONTJA
// ==========================================
void main() {
  // Biztosítjuk, hogy a Flutter motor (engine) teljesen elinduljon, 
  // mielőtt bármilyen platform-specifikus (pl. fájlrendszer) kód lefutna.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DuckyReporterApp());
}

// A legfőbb, gyökér (Root) Widget. 
// Ez határozza meg az app globális kinézetét (Téma, Színek).
class DuckyReporterApp extends StatelessWidget {
  const DuckyReporterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Eltünteti a csúnya "DEBUG" szalagot a jobb felső sarokból
      title: 'Ducky Reporter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), // A fő márkaszinünk a Kékeszöld (Teal)
        useMaterial3: true, // A legújabb, modern Google dizájn-nyelv használata
      ),
      home: const MainDashboard(), // Az első képernyő, ami betöltődik
    );
  }
}

// ==========================================
// A FŐKÉPERNYŐ (NAVIGÁCIÓS VÁZ)
// ==========================================
// Ez a widget csak egy "keret". Tartalmazza a felső sávot (AppBar) és az alsó menüt (BottomNavigationBar),
// a közepén (body) pedig cserélgeti a képernyőket aszerint, hogy mit nyomtunk meg alul.
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  // Ez a változó tárolja, hogy épp melyik fülön vagyunk (0 = Sablonok, 1 = Riportok)
  int _currentIndex = 0;

  // A listában tároljuk a két főképernyőnket. Az indexük (0 és 1) alapján hivatkozunk rájuk.
  final List<Widget> _screens = [
    const TemplateListScreen(),
    const ReportListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ducky Reporter', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // A jobb felső sarokban lévő fogaskerék ikon.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Beállítások',
            onPressed: () {
              // Ha rányomunk, a Navigator ráhelyezi a Beállítások képernyőt az aktuálisra.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      // A _screens listából azt a képernyőt mutatjuk, amelyiknek az indexe a _currentIndex
      body: _screens[_currentIndex],
      
      // Az alsó navigációs sáv
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Ha rányomnak egy gombra alul, frissítjük a State-et (állapotot), 
          // amitől az egész keret újra rajzolódik az új képernyővel.
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Sablonok',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_special),
            label: 'Riportok',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. SABLONOK (TEMPLATES) LISTÁJA
// ==========================================
class TemplateListScreen extends StatefulWidget {
  const TemplateListScreen({super.key});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  List<ReportTemplate> _templates = []; // Itt tároljuk a beolvasott sablonokat
  bool _isLoading = true; // Mutatja-e a töltés-karikát a képernyő közepén

  @override
  void initState() {
    super.initState();
    // Amikor ez a képernyő először betöltődik a memóriába, azonnal meghívjuk a fájlolvasót.
    _loadTemplates(); 
  }

  // Beolvassa a '.json' fájlokat a Templates mappából.
  Future<void> _loadTemplates() async {
    setState(() { _isLoading = true; });

    try {
      final String templatesPath = await FileManager.getTemplatesPath();
      final Directory dir = Directory(templatesPath);
      
      if (await dir.exists()) {
        // Kikeressük az összes fájlt, ami '.json'-ra végződik
        final List<FileSystemEntity> files = dir.listSync().where((file) => file.path.endsWith('.json')).toList();
        
        final List<ReportTemplate> loadedTemplates = [];
        for (var file in files) {
          // Beolvassuk a nyers szöveget, majd átalakítjuk ReportTemplate objektummá
          final String fileContent = await File(file.path).readAsString();
          loadedTemplates.add(ReportTemplate.fromJson(fileContent));
        }

        setState(() { _templates = loadedTemplates; });
      }
    } catch (e) {
      debugPrint('Hiba a sablonok betöltésekor: $e');
    } finally {
      // Akár sikerült, akár nem, a töltés-ikont mindenképp eltüntetjük a végén.
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Törli a kiválasztott sablon JSON fájlját és a hozzá tartozó DOCX másolatot is.
  Future<void> _deleteTemplate(ReportTemplate template) async {
    // 1. Megkérdezzük a felhasználót, biztos-e benne (AlertDialog)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sablon törlése'),
        content: Text('Biztosan törölni szeretnéd a(z) "${template.templateName}" sablont?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    // 2. Ha igent nyomott, megkeressük a fájlokat és töröljük őket
    if (confirm == true) {
      final String templatesPath = await FileManager.getTemplatesPath();
      final File jsonFile = File('$templatesPath/${template.templateName}.json');
      final File docxFile = File(template.docxPath);

      if (await jsonFile.exists()) await jsonFile.delete();
      if (await docxFile.exists()) await docxFile.delete();

      // Frissítjük a listát a képernyőn
      _loadTemplates();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sablon törölve!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Ha tölt, mutatunk egy karikát
          : _templates.isEmpty
              ? const Center(
                  // Ha nincs egyetlen sablon sem, mutatunk egy segítő szöveget
                  child: Text(
                    'Nincsenek még sablonjaid.\nKattints az "Új Sablon" gombra!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              // Ha vannak sablonok, egy görgethető listát (ListView) építünk belőlük
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.description, color: Colors.teal),
                        ),
                        title: Text(template.templateName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Mezők száma: ${template.fields.length}\n${template.docxPath.split(Platform.pathSeparator).last}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Zöld Play Gomb: Indítja az Adatkitöltőt!
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.green),
                              tooltip: 'Riport Kitöltése',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    // Átadjuk a kiválasztott sablont a kitöltő képernyőnek
                                    builder: (context) => ReportFillerScreen(template: template),
                                  ),
                                );
                              },
                            ),
                            // 2. Piros Kuka Gomb: Törlés
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Törlés',
                              onPressed: () => _deleteTemplate(template),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      // A lebegő "+" gomb a jobb alsó sarokban
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // A program itt "megáll" és megvárja (await), amíg visszatérünk a TemplateEditorScreen-ről
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TemplateEditorScreen()),
          );
          // Amint visszatértünk, azonnal újratöltjük a listát, hogy a friss sablon is megjelenjen!
          _loadTemplates(); 
        },
        icon: const Icon(Icons.add),
        label: const Text('Új Sablon'),
      ),
    );
  }
}

// ==========================================
// 2. RIPORTOK (KÉSZ MUNKÁK) LISTÁJA
// ==========================================
class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  List<ReportData> _reports = []; // Itt tároljuk a már kitöltött JSON riportokat
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // Beolvassa a kitöltött '.json' riportokat a Reports mappából
  Future<void> _loadReports() async {
    setState(() { _isLoading = true; });

    try {
      final String reportsPath = await FileManager.getReportsPath();
      final Directory dir = Directory(reportsPath);
      
      if (await dir.exists()) {
        final List<FileSystemEntity> files = dir.listSync().where((file) => file.path.endsWith('.json')).toList();
        
        final List<ReportData> loadedReports = [];
        for (var file in files) {
          final String fileContent = await File(file.path).readAsString();
          loadedReports.add(ReportData.fromJson(fileContent));
        }

        // Rendezzük a listát, hogy a legújabb fájl legyen legfelül (ABC és dátum sorrend csökkenőben)
        loadedReports.sort((a, b) => b.reportName.compareTo(a.reportName));

        setState(() { _reports = loadedReports; });
      }
    } catch (e) {
      debugPrint('Hiba a riportok betöltésekor: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Kitöltött riport (JSON) törlése a memóriából
  Future<void> _deleteReport(ReportData report) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Riport törlése'),
        content: Text('Biztosan törölni szeretnéd a(z) "${report.reportName}" riportot?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mégse')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final String reportsPath = await FileManager.getReportsPath();
      final File jsonFile = File('$reportsPath/${report.reportName}.json');

      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      _loadReports(); // Törlés után lista frissítése
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Riport törölve!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(
                  child: Text(
                    'Még nincsenek kitöltött riportjaid.\nMenj a Sablonok fülre és nyomj a zöld Play gombra!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                          child: const Icon(Icons.folder_special, color: Colors.indigo),
                        ),
                        title: Text(report.reportName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Sablon: ${report.templateName}\nDátum: ${report.date}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ==========================================
                            // AZ EXPORTÁLÓ GOMB (A Főattrakció)
                            // ==========================================
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                              tooltip: 'Exportálás (DOCX generálás)',
                              onPressed: () async {
                                // 1. Mielőtt exportálunk, meg kell keresnünk az eredeti "Szülő" sablont, 
                                //    amiből ez a riport készült, hogy meglegyen az üres DOCX útvonala.
                                final templatesPath = await FileManager.getTemplatesPath();
                                final templateFile = File('$templatesPath/${report.templateName}.json');

                                if (await templateFile.exists()) {
                                  // 2. Beolvassuk a szülő sablont objektummá
                                  final templateContent = await templateFile.readAsString();
                                  final parentTemplate = ReportTemplate.fromJson(templateContent);

                                  // 3. Beküldjük a kitöltött Riportot és az üres Szülő Sablont a Motorba!
                                  await DocxEngine.generateDocx(context, report, parentTemplate);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Hiba: Az eredeti sablon nem található!'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Törlés',
                              onPressed: () => _deleteReport(report),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==========================================
// 3. BEÁLLÍTÁSOK KÉPERNYŐ (ENGEDÉLYEK ÉS MAPPÁK)
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Ebben a változóban tartjuk nyilván az aktuálisan kiválasztott mappa útvonalát
  String? _currentPath; 

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  // Betölti a FileManagerből, hogy van-e már elmentett mappa
  Future<void> _loadCurrentPath() async {
    final path = await FileManager.getWorkingDirectory();
    setState(() {
      _currentPath = path;
    });
  }

  // Ez fut le, amikor rányomnak a "Mappa Létrehozása" gombra
  Future<void> _pickDirectory() async {
    // 1. Megkérjük az Androidot, hogy adjon hozzáférést a telefon belső tárhelyéhez
    var statusManage = await Permission.manageExternalStorage.request();
    var statusStorage = await Permission.storage.request();

    // Ha megkaptuk az engedélyt...
    if (statusManage.isGranted || statusStorage.isGranted) {
      
      // 2. Megcélozzuk a telefon Publikus, mindenki által látható "Documents/DuckyReporter" mappáját
      final Directory publicDocDir = Directory('/storage/emulated/0/Documents/DuckyReporter');
      
      // Ha még nem létezik, létrehozzuk
      if (!await publicDocDir.exists()) {
        await publicDocDir.create(recursive: true);
      }

      // 3. Elmentjük ezt az útvonalat a FileManagerbe, ami le fogja generálni az almappákat is (Templates, Reports, stb.)
      await FileManager.saveWorkingDirectory(publicDocDir.path);
      
      // 4. Frissítjük a képernyőt, hogy a piros hibaüzenet eltűnjön, és kiírjuk a zöld útvonalat.
      setState(() {
        _currentPath = publicDocDir.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Munkamappa sikeresen létrehozva a Dokumentumok között!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Ha a felhasználó megtagadta az engedélyt (Deny)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba: Nem adtál tárhely engedélyt!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beállítások', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Munkakönyvtár beállítása',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Az alkalmazás a telefon hivatalos "Dokumentumok / DuckyReporter" mappájába fogja menteni a sablonokat és a riportokat.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            
            // Egy szép, dobozos kijelző, ami mutatja a jelenlegi állapotot
            Container(
              padding: const EdgeInsets.all(15),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  // Ha nincs mappa beállítva, pirosra festjük a keretet, különben Kékeszöldre
                  color: _currentPath == null ? Colors.red.shade300 : Colors.teal.shade300,
                  width: 2,
                ),
              ),
              child: Text(
                _currentPath ?? 'FIGYELEM: Még nincs mappa beállítva!',
                style: TextStyle(
                  fontSize: 16,
                  color: _currentPath == null ? Colors.red : Colors.black87,
                  fontWeight: _currentPath == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // A mappageneráló gomb
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickDirectory,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Mappa Létrehozása', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}