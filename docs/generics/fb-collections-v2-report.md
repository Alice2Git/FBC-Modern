# Raport: reparatiile cerute de fb-collections-v2 (b01-b11)

Raspuns din **FBC-Modern**, ramura `lambda-fixes` (`Alice2Git/FBC-Modern`), la cererea din `PROMPT_COMPILATOR.md`. Toate cele 11 probleme sunt tratate: 9 reparate, iar b04 si b06 au primit ce se putea face fara sa se schimbe limbajul (detalii la fiecare). Folderul `fb-collections-v2` nu a fost modificat: a fost doar copiat si compilat.

Ramura e la **`7498899`**. Contine cele trei compilatoare recompilate (`toolchains/fbc-modern-windows/fbc64.exe`, `fbc32.exe`, `toolchains/fbc-modern-linux/bin/fbc`) si headerele actualizate in ambele `toolchains/`.

## Pe fiecare problema

| # | stare | commit | cauza, pe scurt |
|---|---|---|---|
| 1 | reparat anterior | (lambda-fixes) | ramane test de regresie; verificat din nou: afiseaza doar `maria` |
| 2 | **reparat** | `364964e` | antetul unei lambda e redat in mijlocul expresiei, iar la granitele de instructiune ale acelei redari se compilau corpurile generice in asteptare, cu parserul inca „in expresie” (`FB_PARSEROPT_ISEXPR`): orice apel de SUB din acele corpuri devenea `error 17` |
| 3 | **reparat** | `ff8b878` | `FB.Array.Push` realoca inainte sa citeasca `v`; acum copiaza `v` inainte de realocare, si doar cand realocarea chiar are loc |
| 4 | **reparat** (b04b); b04 da acum un mesaj corect | `3c92da4` | `for each` cauta protocolul doar printre membrii proprii ai tipului; acum cauta si in clasele de baza. b04 ramane eroare, pe buna dreptate: `GetIterator` intoarce `T ptr`, iar un pointer nu e un iterator. Acum spune asta: `error 357: GetIterator( ) must return an iterator TYPE ..., it returns long ptr` |
| 5 | **reparat** | `3e1bdce` | eroarea e raportata acum pe linia membrului (7), nu pe linia `type` (aceeasi cauza ca la 11) |
| 6 | **mesaj clar**; metodele generice nu sunt implementate | `f9a4022` | `error 358: Generic methods are not supported, a member cannot have type parameters of its own; use a generic SUB or FUNCTION taking the object as a parameter` |
| 7 | **reparat** | `dff7b99` | nu era coliziunea `f`/`F`: un tip pointer-la-functie scris intr-o procedura (tipul unei lambda sau o variabila `dim p as function(...)`) e sters la `end sub`, dar instantierea generica il folosea mai tarziu, cand isi compila corpul — citea memorie eliberata |
| 8 | **reparat** | `484ca38` | vezi mai jos |
| 9 | **reparat** | `ff8b878` | supraincarcarile `FB.HashOf` sunt `private`, ca `HashBytes` si `HashInt` de langa ele |
| 10 | **reparat** | `484ca38` | aceeasi cauza ca 8 |
| 11 | **reparat** | `3e1bdce` | redarea unui corp generic nu numara liniile, iar citatul era luat din fisierul intrerupt; acum linia si citatul sunt ale liniei vinovate, din fisierul genericului (header inclus, daca e cazul) |

### 8 / 10, pe larg

Instantierea nu strica starea parserului, cum banuiati. Problema e alta:
- O cautare de simbol intoarce un „lant” alocat dintr-un buffer circular de 4096 de intrari.
- Corpurile membrilor unei instantieri noi sunt compilate la urmatoarea granita de instructiune. In acel moment, lexerul citise deja primul token al instructiunii urmatoare (`Arata`) si ii cautase simbolul.
- Corpurile lui `xList` fac de cateva ori 4096 de cautari (la b08, bufferul s-a reluat de 3 ori), deci lantul lui `Arata` era suprascris cu ce cautase redarea ultima data. De aici erorile despre codul apelantului: 42, 215, 202, 214, iar pe Linux `parameter 1 (k) of Arata()`, desi parametrul se numeste `b`.

De aici si ce ati masurat:
- **Depinde de marimea genericului, nu de forma lui.** De aceea niciun generic mic nu reproducea problema.
- **Depinde de primul token al instructiunii urmatoare.** Parserul lui `dim` nu foloseste lantul, deci „incalzirea” cu `dim` mergea. `print` si orice apel pica.

Acum fiecare redare are propriul buffer. Fara eroarea din fata, apelul era legat de alt simbol si emitea cod gresit (cu gas64, posibil fara nicio eroare).

**Liniile de „incalzire” (cele 194) nu mai sunt necesare.** Criteriul 3 e verificat pentru `xSet`, `xList`, `xMap`, `xSortedSet` si `xTree`: toate compileaza si afiseaza `true`. Pe compilatorul vechi dadeau, in ordine, erorile 42, 214, 202, 58 si 42.

### De ce nu exista metode generice (6)

Ar insemna o functionalitate noua de limbaj, nu o reparatie:
- membri adaugati unui TYPE instantiat dupa ce e complet, cate unul pentru fiecare lista de argumente folosita la apeluri;
- mangling propriu;
- deducerea tipurilor dintr-un apel de metoda;
- interactiunea cu metodele virtuale.

Riscul pentru restul compilatorului e mare, asa ca am pus doar mesajul clar si am trecut limita in `docs/generics/generics.txt` si in README. Pot fi facute separat, daca le vreti. Pana atunci, ocolirile voastre raman cele corecte: o functie libera generica, sau parametrul de tip pus pe TYPE.

## In plus, gasite pe drum

- **`5a42927`:** instantierile generice apar in mesaje si in `typeof( )` asa cum sunt scrise. De exemplu, `WIter( of long, It( of long ), ... )` in loc de `$GEN$$...__FBGENINST`.
- **Documentatie:** exemplul `HashOf` din `docs/map/map.txt` e acum `private`, cu explicatia. `docs/for_each/iterator-protocol.txt` spune ca membrii mosteniti conteaza.

## Criteriul de acceptare

1. **Reproducerile** se comporta ca in coloana a patra, pe Linux si pe win64. b04 si b06 dau mesajele de mai sus.
2. **Suita bibliotecii:** 1444 de verificari, „toate testele au trecut”, iar cele 10 fisiere din `fail\` sunt respinse (cu aceleasi mesaje ca inainte, pe Linux). Configuratiile rulate:
   - Linux;
   - win64 cu gcc (`run_tests.bat`, sub Wine);
   - win64 cu `-gen gas64`.

   **Nerulat:** `fbc32.exe` s-a compilat, dar aici nu exista Wine pe 32 de biti. Configuratia `run_tests.bat <cale>\fbc32.exe` trebuie rulata la voi.
3. **Criteriul 3:** indeplinit pentru toate cele cinci containere.

Pentru fiecare reparatie exista un test nou in suita FBC-Modern. Suitele proprii ale compilatorului trec:
- `tests/generics` 67/67, pe gcc si gas64, Linux si win64;
- `log-tests` 1756/1756;
- `errors` si `warnings`, fara nicio schimbare in afara testelor noi;
- `unit-tests` pe win64, sub Wine: 1.594.934 de verificari, 14 esecuri. Aceleasi 14 apar si cu compilatorul de dinaintea reparatiilor, in acelasi mediu, iar rezultatele sunt identice suita cu suita:
  - `threadcall_` (11): cele cunoscute din README, lipsa libffi;
  - `file/pipe` (1): testul cheama `ls`, pe care `cmd`-ul din Wine nu il are;
  - `chrono/zones` (2): testul asteapta ora de vara, iar mediul de test e in UTC.
