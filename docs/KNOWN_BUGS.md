# FBC-Modern: bug-uri cunoscute (noiembrie 2026)

Lista bug-urilor găsite în compilatorul FBC-Modern (ramura `lambda-fixes`) în timpul lucrului la
NetKit și UserKit. Fiecare bug **nereparat** de mai jos a fost reprodus cu programul minimal din
dreptul lui, pe linux-x86_64, cu toolchain-ul `toolchains/fbc-modern-linux` de la commit-ul
`61f51d8` (după PR #1 și #2). Lista se actualizează pe măsură ce bug-urile se repară.

| # | Bug | Gravitate | Stare |
|---|---|---|---|
| 1 | `for each` peste un container întors de o funcție: memorie eliberată | **mare** (crash / date greșite) | nereparat; ocolit în kit-uri |
| 2 | `FB.Array` instanțiat într-un namespace cu nume de o literă (`K`, `I`...) | medie | nereparat; ocolit |
| 3 | `extern ... alias` într-un namespace e tot decorat cu namespace-ul | medie | nereparat; ocolit |
| 4 | gas64: obiectele n-au secțiunea `.note.GNU-stack` (avertisment `ld`) | mică | nereparat; ocolit |
| 5 | `-gen gcc -O 2 -exx`: avertismente false `-Wmaybe-uninitialized` | mică | nereparat; ocolit |
| 6 | `end iif( ... )` dă „Illegal END” | foarte mică | nereparat |
| 7 | test instabil `chrono/clocks.bas:227` | test, nu compilator | nereparat |
| 8 | gas64 Linux: structuri întoarse în registre stocate greșit | **mare** | **reparat** (PR #2) |

Nu sunt bug-uri, dar merită știute: `ThreadDetach` cere `#include "fbthread.bi"`; `command()` e gol
într-un constructor de modul; un parametru nu poate avea același nume ca o metodă sau ca o procedură
declarată înainte („Duplicated definition”); `for each` nu merge peste o listă literală `{...}`.

---

## 1. `for each` peste un container întors de o funcție — memorie eliberată

**Ce se întâmplă.** În `for each x in F( )`, unde `F` întoarce un container prin valoare (de exemplu
`FB.Array( of string )`), obiectul temporar întors de `F` e distrus **înainte** de buclă. Iteratorul
lucrează apoi pe memorie eliberată: crash (segmentation fault) sau date greșite.

```basic
#include once "fb/array.bi"
function Items( ) as FB.Array( of string )
	dim a as FB.Array( of string )
	for i as long = 1 to 3 : a.Push( "item" & i & string( 40, "x" ) ) : next
	return a
end function
for each it in Items( )
	print left( it, 5 )
next
print "done"
```

- `fbc b1.bas` → **Segmentation fault**, nu se afișează nimic.
- `fbc -exx b1.bas` → `runtime error 6 (out of bounds array access) at line 85 of fb/array.bi::VALUE(), 'ITEMS' accessed with invalid index = 1, must be between 0 and 0`.

**Ocolire.** Containerul se pune întâi într-o variabilă: `dim as FB.Array( of string ) v = Items( ) : for each it in v`.
În NetKit / UserKit iteratorii listelor lucrează pe o copie, așa că `for each a in DnsResolve(...).Send()` merge.

**Unde trebuie reparat.** Lowering-ul lui `for each` (desugaring-ul cu `GetIterator`) trebuie să
păstreze temporarul în viață până la sfârșitul buclei (să-l lege de o variabilă ascunsă a scope-ului
buclei), cum face C++ cu range-for. Grav pentru că pare cod corect și merge uneori.

## 2. `FB.Array` instanțiat într-un namespace cu nume de o literă

**Ce se întâmplă.** Corpurile generice din `fb/array.bi` folosesc variabile locale `k`, `i`... La
instanțiere, un namespace al apelantului cu același nume (FreeBASIC nu ține cont de litere mari / mici)
le ascunde, iar instanțierea pică.

```basic
#include once "fb/array.bi"
namespace K
	type Item : as long v : end type
	dim shared as FB.Array( of Item ) items
end namespace
print "ok"
```

```
fb/array.bi(180) error 120: Expected period ('.'), found 'as' in 'for k as long = this.num to i+1 step -1'
  in instantiation of 'Array( of K.ITEM )'
```

Cu `namespace Q` merge. **Ocolire:** alt nume pentru namespace. **Unde trebuie reparat:** căutarea
numelor la replay-ul unui corp generic nu trebuie să vadă namespace-urile locului de instanțiere
înaintea variabilelor locale ale corpului (înrudit cu reparația din changelog pentru variabilele
numite ca un parametru de tip, `t` / `e`).

## 3. `extern ... alias` într-un namespace e tot decorat

```basic
namespace N
	extern "C"
		extern my_environ alias "environ" as zstring ptr ptr
	end extern
end namespace
print *N.my_environ[0] <> ""
```

```
ld: b3.o: in function `main': undefined reference to `N::environ'
```

Cu `alias` (și `extern "C"`) numele de legare ar trebui să fie exact `environ`. **Ocolire:** declarația
în afara namespace-ului. De verificat dacă și fbc 1.20 original face la fel (atunci e un bug moștenit).

## 4. gas64: lipsește `.note.GNU-stack`

Orice program compilat cu `-gen gas64` pe Linux, chiar și `print "hi"`, dă la legare:

```
ld: warning: b5.o: missing .note.GNU-stack section implies executable stack
ld: NOTE: This behaviour is deprecated and will be removed in a future version of the linker
```

**Ocolire:** `-Wl -z,noexecstack` (îl folosesc scripturile de test ale kit-urilor). **Reparație:**
backend-ul gas64 trebuie să emită `.section .note.GNU-stack,"",@progbits` la sfârșitul fișierului
`.asm` pe Linux / FreeBSD (backend-ul gcc îl primește automat de la gcc).

## 5. `-gen gcc -O 2 -exx`: avertismente false `-Wmaybe-uninitialized`

Codul C generat cu `-exx` (salturi calculate pentru verificări) face gcc 13 să dea avertismente
`-Wmaybe-uninitialized` false. Reprodus pe NetKit (5 avertismente, din `nk_SysInterfaces` în
`NetUnix.bas`):

```
fbc -w all -gen gcc -O 2 -exx -c -i NetKit NetKit/tests/test_netkit.bas
```

Un program mic nu le-a reprodus. **Ocolire:** configurația `-O 2` din teste rulează fără `-exx`.

## 6. `end iif( ... )` dă „Illegal END”

```basic
end iif( 1 = 1, 0, 1 )        '' error 33: Illegal 'END'
```

`end (iif( 1 = 1, 0, 1 ))` și `end 1 + 0` merg. Parserul ia `END IIF` drept sfârșitul unui bloc. Probabil
moștenit din fbc original; neverificat.

## 7. Test instabil `chrono/clocks.bas:227`

`CU_ASSERT( CpuClock.ProcessTime( ).Ticks >= th.Ticks )` pică din când în când pe Linux, cu ambele
backend-uri (cam o dată la 3–7 rulări). `ProcessTime` vine din `getrusage` (microsecunde), `ThreadTime`
din `clock_gettime( CLOCK_THREAD_CPUTIME_ID )` (nanosecunde), deci timpul firului poate ieși puțin mai
mare decât al procesului. **Reparație posibilă:** pe Linux `ProcessTime` din
`clock_gettime( CLOCK_PROCESS_CPUTIME_ID )`, sau o toleranță în test.

## 8. (reparat) gas64 Linux: structuri întoarse în registre

Reparat în PR #2 (`1513fa3`, integrat în `lambda-fixes`): orice program cu `fb/chrono.bi` crăpa
compilatorul sub `-gen gas64`; structurile de 1–8 octeți suprascriau stiva apelantului; o funcție cu mai
multe `return Apel( )` întorcea rezultatul greșit. Test de regresie: `src/tests/functions/udt-result-regs.bas`.
Windows nu era afectat.
