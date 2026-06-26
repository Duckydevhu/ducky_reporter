# Ducky Reporter 🦆

A **Ducky Reporter** egy offline működő Flutter mobilalkalmazás, amely megkönnyíti és automatizálja a helyszíni jelentések, jegyzőkönyvek és űrlapok kitöltését, majd azokból azonnali Microsoft Word (`.docx`) dokumentumok generálását.

## ✨ Fő funkciók

* **Dinamikus Sablonrendszer:** Bármilyen meglévő `.docx` fájl betallózható sablonként.
* **Okos Űrlapok (Smart Forms):** A sablonhoz rendelt mezők alapján az alkalmazás automatikusan legenerálja a kitöltő felületet (Többsoros szöveg, Dátumválasztó, Legördülő lista, Checkbox).
* **100% Offline Működés:** A sablonok, a kitöltött JSON adatok és az exportált fájlok mind a készülék saját tárhelyén maradnak, nincs szükség internetkapcsolatra.
* **Saját Exportáló Motor:** Az app a háttérben közvetlenül manipulálja a `.docx` (XML) fájlokat, kicserélve a helyőrzőket a kitöltött adatokra, anélkül, hogy külső API-t vagy felhőszolgáltatást használna.

## 📁 Fájlrendszer és Tárolás

Az alkalmazás a futtatás során (engedélykérés után) egy saját munkamappát hoz létre a készülék hivatalos **Dokumentumok (Documents)** mappájában:
`Mobileszköz / Documents / DuckyReporter`

Ezen belül három almappa található:
1. `Templates/`: Itt tárolódnak az eredeti `.docx` sablonok és az űrlapok felépítését leíró `.json` fájlok.
2. `Reports/`: A felhasználó által kitöltött, de még nem exportált jelentések nyers `.json` adatai.
3. `Exports/`: A végső, generált `.docx` fájlok, amik azonnal megoszthatók vagy nyomtathatók.

## 📝 Word Sablonok Előkészítése (FONTOS!)

Hogy az exportáló motor helyesen ismerje fel a cserélendő mezőket, a Word dokumentumban a következő formátumot kell használni: `<<MezoNeve>>`

**Kritikus lépés a Word sablon készítésénél:**
A Microsoft Word beépített helyesírás-ellenőrzője hajlamos a háttérben (az XML kódban) "szétdarabolni" az egyedi helyőrzőket. Ennek elkerülése érdekében:
1. A helyőrzőket (pl. `<<UgyfelNeve>>`) először egy egyszerű Jegyzettömbben (Notepad) írd meg.
2. Másold át a Wordbe ("Csak a szöveg megőrzése" opcióval).
3. Jelöld ki a szót, majd a menüben: **Korrektúra -> Nyelv -> Nyelvi beállítások** menüpontban **pipáld be** *"A helyesírás és a nyelvhelyesség ellenőrzésének mellőzése"* opciót!

## 🚀 Telepítés és Fejlesztés (Fejlesztőknek)

A projekt futtatásához a [Flutter SDK](https://flutter.dev/) szükséges.

1. Klónozd le a tárolót (Repository).
2. Nyiss egy terminált a projekt mappájában, és töltsd le a csomagokat:
   flutter pub get

Futtasd az alkalmazást emulátoron vagy csatlakoztatott eszközön:
flutter run

Éles (Release) APK generálása Androidra:
flutter build apk

🛠️ Használt Technológiák és Csomagok
Keretrendszer: Flutter (Dart)
Jogosultságkezelés: permission_handler
Fájl tallózás: file_selector
Fájlrendszer elérés: path_provider
DOCX (ZIP) manipuláció: archive
Dátumkezelés: intl
