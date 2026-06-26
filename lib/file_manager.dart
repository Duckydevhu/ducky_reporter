import 'dart:io'; // A mappák (Directory) és fájlok fizikai létrehozásához, ellenőrzéséhez.
import 'package:shared_preferences/shared_preferences.dart'; // A telefon beépített "kismemóriája", ahova egyszerű adatokat (pl. beállításokat, útvonalakat) tudunk tartósan elmenteni.

/// Ez egy "Segédosztály" (Utility Class), ami a fájlrendszer és a mappák kezeléséért felel.
/// Mivel a metódusai 'static' (statikus) jelölést kaptak, nem kell belőle példányt (object) 
/// létrehozni a használatához, hanem bárhonnan közvetlenül hívhatók, pl.: FileManager.getTemplatesPath()
class FileManager {
  
  // Ez az a "kulcs" (olyan, mint egy szótárban a címszó), ami alapján elmentjük 
  // és később visszakeressük a SharedPreferences-ből a beállított főmappa útvonalát.
  // A '_' a név elején azt jelenti, hogy ez egy privát változó, csak ezen a fájlon belül látszik.
  static const String _workDirKey = 'working_directory';

  // ==========================================
  // 1. BEÁLLÍTOTT MAPPA MENTÉSE ÉS INICIALIZÁLÁSA
  // ==========================================
  /// Ezt hívjuk meg a Beállítások képernyőn, amikor a felhasználó rányom a "Mappa Létrehozása" gombra.
  static Future<void> saveWorkingDirectory(String path) async {
    // Elkérjük a telefon helyi kis adatbázisát (SharedPreferences).
    final prefs = await SharedPreferences.getInstance();
    
    // Eltároljuk a kiválasztott útvonalat (pl. /storage/emulated/0/Documents/DuckyReporter) a kulcsunk alá.
    // Így ha az appot bezárják és újra megnyitják, emlékezni fog rá.
    await prefs.setString(_workDirKey, path);
    
    // Miután megvan a főmappa, azonnal legeneráljuk bele a belső struktúrát (almappákat).
    await _createSubDirectories(path); 
  }

  // ==========================================
  // 2. BEÁLLÍTOTT MAPPA LEKÉRDEZÉSE
  // ==========================================
  /// Visszaadja a korábban elmentett főmappa útvonalát. 
  /// Ha még sosem állították be, akkor null-t ad vissza.
  static Future<String?> getWorkingDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workDirKey);
  }

  // ==========================================
  // 3. ALMAPPÁK LÉTREHOZÁSA (A "Motorháztető" alatt)
  // ==========================================
  /// Ez a privát függvény gondoskodik róla, hogy a főmappán belül meglegyen a 3 alapvető mappánk.
  static Future<void> _createSubDirectories(String basePath) async {
    // Egy egyszerű lista a szükséges mappanevekkel.
    final dirs = ['Templates', 'Reports', 'Exports'];
    
    // Végigmegyünk a listán, és mindegyikhez ellenőrizzük a fizikai útvonalat.
    for (String dir in dirs) {
      final directory = Directory('$basePath/$dir');
      
      // Ha a mappa még nem létezik a telefonon...
      if (!await directory.exists()) {
        // ...akkor létrehozzuk! 
        // A 'recursive: true' azért fontos, mert ha a szülőmappa (DuckyReporter) 
        // valamiért eltűnt volna, akkor azt is újra létrehozza az almappával együtt.
        await directory.create(recursive: true);
      }
    }
  }

  // ==========================================
  // 4. CÉLSPECIFIKUS ÚTVONALAK LEKÉRÉSE (Segédfüggvények)
  // ==========================================
  // Ezeket a függvényeket használjuk az app különböző pontjain (pl. sablonok beolvasásakor, 
  // vagy exportáláskor), hogy mindig pontosan tudjuk, hova kell nyúlni.

  /// Visszaadja a Sablonok (.json és másolt .docx) mappájának pontos útvonalát.
  static Future<String> getTemplatesPath() async {
    final base = await getWorkingDirectory();
    return '$base/Templates';
  }

  /// Visszaadja a Kitöltött űrlap adatok (.json) mappájának pontos útvonalát.
  static Future<String> getReportsPath() async {
    final base = await getWorkingDirectory();
    return '$base/Reports';
  }

  /// Visszaadja a Kész, generált Word fájlok (.docx) mappájának pontos útvonalát.
  static Future<String> getExportsPath() async {
    final base = await getWorkingDirectory();
    return '$base/Exports';
  }
}