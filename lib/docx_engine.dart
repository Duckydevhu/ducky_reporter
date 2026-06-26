import 'dart:io'; // A fájlrendszer (fájlok olvasása/írása) eléréséhez.
import 'dart:convert'; // A karakterkódolásokhoz (pl. bájtok UTF-8 szöveggé alakításához).
import 'package:archive/archive.dart'; // A ZIP fájlok (így a DOCX) ki- és becsomagolásához.
import 'package:flutter/material.dart'; // A UI elemek (pl. SnackBar) miatt.
import 'models.dart'; // Az egyedi adatmodelljeink (ReportData, ReportTemplate).
import 'file_manager.dart'; // A saját útvonalkezelő segédosztályunk.

/// Ez az osztály felelős a DOCX fájlok generálásáért.
/// Mivel a Word dokumentum (DOCX) valójában csak egy átnevezett ZIP archívum,
/// ami XML fájlokat tartalmaz, ki tudjuk csomagolni, módosítani a szöveget, majd visszacsomagolni.
class DocxEngine {
  
  /// A fő aszinkron függvény, ami elvégzi a generálást.
  /// Kap egy [context]-et a UI üzenetekhez, a kitöltött [report]-ot és az eredeti [template]-et.
  static Future<void> generateDocx(BuildContext context, ReportData report, ReportTemplate template) async {
    try {
      // Megkeressük a célmappát, ahova a kész fájlt mentjük majd.
      final exportsDir = await FileManager.getExportsPath();
      
      // Rámutatunk az eredeti, üres DOCX sablonra a telefon tárhelyén.
      final File templateFile = File(template.docxPath);

      // Biztonsági ellenőrzés: ha valamiért letörölték a sablont, dobunk egy hibát, ami a catch ágban landol.
      if (!await templateFile.exists()) {
        throw Exception('A DOCX sablon fájl nem található a megadott útvonalon!');
      }

      // ==========================================
      // 1. DOCX (Zip) KICSOMAGOLÁSA A MEMÓRIÁBA
      // ==========================================
      // Beolvassuk a nyers bájtokat, majd a ZipDecoder segítségével egy feldolgozható listát (Archive) csinálunk belőle.
      final bytes = await templateFile.readAsBytes();
      final oldArchive = ZipDecoder().decodeBytes(bytes);
      
      // Mivel a kibontott archívum (oldArchive) "Read-Only" (csak olvasható),
      // létrehozunk egy teljesen üres, új "dobozt". Ebbe fogjuk átpakolni a fájlokat.
      final newArchive = Archive();

      // ==========================================
      // 2. FÁJLOK VIZSGÁLATA ÉS ÁTPAKOLÁSA
      // ==========================================
      // Végigmegyünk a kibontott ZIP összes fájlján és mappáján.
      for (final file in oldArchive) {
        
        // Csak a konkrét fájlokkal foglalkozunk (mappákkal nem).
        // A Word a tényleges szöveget a 'word/document.xml'-ben tartja, 
        // a fejléceket/lábléceket pedig a 'word/header...' és 'word/footer...' fájlokban.
        if (file.isFile && (file.name == 'word/document.xml' || 
            file.name.startsWith('word/header') || 
            file.name.startsWith('word/footer'))) {
          
          // Ha megtaláltuk a szöveget tartalmazó XML fájlokat, a bájtokat olvasható (UTF-8) szöveggé alakítjuk.
          final contentBytes = file.content as List<int>;
          String content = utf8.decode(contentBytes);

          // ==========================================
          // 3. A CSERÉK (KERESÉS ÉS HELYETTESÍTÉS)
          // ==========================================
          // Végigmegyünk a sablonhoz tartozó összes mezőn (amit a felhasználó az űrlapon kitöltött).
          for (var field in template.fields) {
            
            // Az XML kódolja a kacsacsőröket, ezért a "<<" így néz ki: "&lt;&lt;" a ">>" pedig "&gt;&gt;".
            String placeholder1 = '&lt;&lt;${field.name}&gt;&gt;'; 
            
            // Ha a Word "okos idézőjellé" alakította a kacsacsőröket, arra is felkészülünk.
            String placeholder2 = '«${field.name}»'; 
            
            String replacement = '';

            // Speciális logika a Checkboxokhoz: boolean (igaz/hamis) értékből vizuális Unicode karaktert csinálunk.
            if (field.type == 'checkbox') {
              bool isChecked = report.answers[field.name] ?? false;
              replacement = isChecked ? '☑' : '☐';
            } else {
              // Szöveg vagy dátum esetén simán beillesztjük a választ. Ha null, akkor egy üres stringet (eltüntetjük a taget).
              replacement = report.answers[field.name]?.toString() ?? ''; 
            }

            // Végrehajtjuk a tényleges cserét az XML szövegben.
            content = content.replaceAll(placeholder1, replacement);
            content = content.replaceAll(placeholder2, replacement);
          }

          // ==========================================
          // 4. MÓDOSÍTOTT FÁJL BEILLESZTÉSE
          // ==========================================
          // A módosított (kicserélt) XML szöveget visszaalakítjuk bájtokká.
          final newContentBytes = utf8.encode(content);
          
          // Létrehozunk egy új fájl-objektumot ugyanazzal a névvel, de az új tartalommal, és betesszük az új ZIP-be.
          newArchive.addFile(ArchiveFile(file.name, newContentBytes.length, newContentBytes));
          
        } else {
          // Ha a fájl nem XML (pl. képek, betűtípusok, formázási beállítások),
          // akkor érintetlenül átemeljük a régi archívumból az újba.
          newArchive.addFile(file);
        }
      }

      // ==========================================
      // 5. ÚJ DOCX FÁJL MENTÉSE ÉS VISSZAJELZÉS
      // ==========================================
      // A feltöltött, új archívumot visszacsomagoljuk ZIP (DOCX) formátumba.
      final encodedBytes = ZipEncoder().encode(newArchive);
      if (encodedBytes == null) throw Exception('Nem sikerült becsomagolni a fájlt.');

      // Létrehozzuk a kimeneti fájlt a Reports mappában, a riport saját nevével.
      final outputFile = File('$exportsDir/${report.reportName}.docx');
      await outputFile.writeAsBytes(encodedBytes);

      // Ellenőrizzük, hogy a UI (Képernyő) még létezik-e, mielőtt üzenetet küldünk rá.
      // (Erre azért van szükség, mert az aszinkron művelet alatt a felhasználó elnavigálhatott onnan).
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sikeres Exportálás!\nMentve: Exports/${report.reportName}.docx'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Hibakezelés: ha bármi elszáll (pl. jogosultság, hiányzó fájl), kiírjuk a felhasználónak pirossal.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba az exportáláskor: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}