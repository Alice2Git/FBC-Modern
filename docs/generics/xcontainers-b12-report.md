# Raport: b12 din xContainers

Raspuns din **FBC-Modern**, ramura `lambda-fixes` (`Alice2Git/FBC-Modern`), la cererea din `xContainers/bugs/PROMPT_COMPILATOR_b12.md`. Folderul `xContainers` nu a fost modificat: a fost doar copiat si compilat.

## Starea

**Reparat.** Reproducerea afiseaza `true` de fiecare data, cu gcc, cu `-exx` si cu `-gen gas64`, pe `fbc64` si pe `fbc32`.

| commit | ce contine |
|---|---|
| `d86e2ce` | reparatia si testul `src/tests/generics/instantiate-mid-expression-temps.bas` |
| `0f64067` | `fbc64.exe` si `fbc32.exe` din `toolchains/fbc-modern-windows`, reconstruite cu reparatia |

## Cauza

Temporarele care asteapta sa fie distruse (de exemplu sirul construit din `"verde"` pentru un parametru `byref as const string`) stau intr-o lista globala, `ast.dtorlist`. Lista e golita de primul `astAdd( )` din ORICE procedura: se presupune ca, pe durata unei expresii, nu se compileaza alt corp de procedura.

Instantierea unui generic incalca presupunerea. Cand `Deriv( of string )` apare prima data in mijlocul apelului, TYPE-ul e redat pe loc, iar `END TYPE` compileaza imediat corpurile membrilor impliciti (constructorul care pune tabela virtuala, destructorul, LET). Primul `astAdd( )` din constructor golea lista apelantului:
- distrugerea temporarului ajungea in constructor, unde temporarul nu exista. gcc respingea codul C (`'TMP$7$0' undeclared`). Cu gas64, constructorul elibera o adresa din cadrul de stiva gresit, iar programul crapa;
- apelantul nu mai distrugea temporarul deloc.

Nu tine de metodele virtuale in sine. Conteaza doar ca tipul are un constructor implicit cu corp. La fel pateste un generic cu un camp `string`, care are si destructor, constructor de copiere si LET implicite.

**Despre nedeterminism:** aici, pe aceeasi sursa, rezultatul a fost mereu acelasi. Numele temporarului (`TMP$7$0`, `TMP$18$0`) depinde de cate simboluri s-au creat inainte, deci se schimba de la o sursa la alta si cu optiunile. Daca gcc respinge codul sau programul crapa tine de unde aterizeaza temporarul, nu de compilator.

## Reparatia

`genSaveState( )` / `genRestoreState( )` salveaza starea parserului in jurul ORICAREI redari, generica sau lambda. Acum pun deoparte si lista de temporare, cu tot cu stiva ei de scopuri (cookie-urile IIF): `astDtorListPark( )` / `astDtorListUnpark( )` din `ast-misc.bas`. Pe durata redarii, corpurile compilate lucreaza pe o lista goala, iar la sfarsit lista apelantului revine neatinsa. Temporarul e distrus acolo unde ii e locul, dupa apel:

    fb_StrAssign( (void*)&TMP$7$0, -1ll, (void*)"verde", 6ll, 0 );
    boolean vr$6 = IA( (FBSTRING*)&TMP$7$0, (struct $4BazaI8FBSTRINGE*)&TMP$11$0 );
    fb_PrintBool( 0, vr$6, 1 );
    fb_StrDelete( (FBSTRING*)&TMP$7$0 );

Reparatia acopera si inchiderile lambda: si ele sunt generice instantiate in mijlocul expresiei.

## Verificare

Compilatoarele au fost construite si verificate nativ pe Windows 10, cu toolchain-ul din `toolchains/fbc-modern-windows`.

1. **Reproducerea** si variantele ei afiseaza rezultatul corect cu gcc, `-exx`, `-gen gas64` si `-gen gas64 -exx`. Compilatorul vechi pica pe fiecare dintre ele:
   - forma raportata;
   - un generic cu un camp `string`, cu temporare de o parte si de alta;
   - acelasi lucru dintr-un SUB, cu o variabila locala in expresie;
   - `lista.Contains( "verde", xEqualsOf( of string )( ) )` ca prima folosire, cu biblioteca.
2. **Suita bibliotecii**, cu `teste\run_all.bat` pe o copie: toate cele trei configuratii au trecut. Fiecare are 1464 de verificari, 10 fisiere `fail\` respinse cu eroarea declarata si 15 exemple cu iesirea asteptata.
3. **b01-b11** se comporta la fel ca inainte.
4. **Testul nou** `src/tests/generics/instantiate-mid-expression-temps.bas` pica pe compilatorul vechi si trece pe cel nou.
5. **Suitele compilatorului** au fost rulate ca diferenta intre compilatorul vechi si cel nou, pentru ca `make` nu exista pe aceasta masina:
   - toate cele 1767 de teste cu `TEST_MODE` din `src/tests`, cu `-exx`, pe gcc si pe gas64: singura diferenta e testul nou;
   - `tests/generics`, pe ambele backend-uri: trec toate cele 66 de teste cu un singur fisier si cele trei teste multi-modul (`multimodule`, `hash-mm`, `lambda-mm`);
   - golden files din `errors` si `warnings`, pe cele cinci tinte: identice.

**Nerulat:** `unit-tests` (cer `make`) si compilatorul Linux. `toolchains/fbc-modern-linux/bin/fbc` NU e reconstruit si nu are reparatia, pentru ca aici nu exista o masina Linux.
