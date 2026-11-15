# Documentazione tecnica

Questo file raccoglie la parte tecnica del progetto: memoria, formato dei dati, temporizzazione dell'infrarosso, gestione degli errori, test e tutto quello che abbiamo scoperto sull'hardware. Per l'uso del programma vedi `README.md`. Per le regole di sviluppo vedi `../AGENTS.md`.

Le affermazioni sono etichettate: **verificato** (provato su emulatore o su console), **ipotesi** (coerente con i dati, non provata), **ignoto**.

## Indice

1. Architettura
2. Avvio
3. Memoria della console (WRAM)
4. SRAM della cartuccia
5. Campionamento infrarosso
6. Velocità della CPU
7. Gestione degli errori
8. Interfaccia
9. Audio
10. Build
11. Test
12. Cosa abbiamo scoperto sull'hardware
13. Limiti e prossimi passi
14. Hardware usato per le prove
15. Copertura dei test
16. Riferimenti

## 1. Architettura

```
inc/            costanti, nomi dei registri, macro (nessun numero magico nel codice)
src/boot/       punto di ingresso e main
src/hal/        accesso all'hardware: clock, lcd, joypad, sram, infrared, audio, vram_text
src/lib/        funzioni generiche di memoria
src/logic/      logica applicativa e schermate
src/data/       solo tabelle: font, stringhe, dialoghi, palette, tastiera, melodie, firma
tests/          framework in assembly, casi, runner Python, harness di flusso
docs/           questa documentazione
```

Regole:
- Solo `src/hal/` e `src/lib/` toccano i registri hardware.
- Nessun commento nel codice: i nomi spiegano l'intento. Vale anche per Makefile e Python.
- Ogni stato in RAM ha un solo modulo proprietario.

Moduli principali di `src/logic/`:

| Modulo | Compito |
|---|---|
| `application` | ciclo principale: lista schede, apertura scheda, azioni |
| `storage` | directory, schede, segnali, campioni, nomi unici, ripristino |
| `sram_probe` | misura delle banche SRAM a ogni avvio |
| `sram_diagnostic` | diagnostica con SELECT all'avvio |
| `signal_capture` | attesa e cattura del segnale |
| `list_view` | lista a scorrimento con cursore |
| `card_list_screen`, `signal_list_screen` | schermate delle liste |
| `name_entry_screen`, `keyboard`, `name_buffer` | inserimento del nome |
| `confirm_dialog` | tutte le conferme, guidate da descrittori in `src/data/dialogs.asm` |
| `workflow_*` | sequenze: primo segnale, nuovo segnale, scheda, invio, eliminazione |
| `error_screen`, `error_handling` | errori |
| `jingle` | melodie |

## 2. Avvio

Ordine in `src/boot/main.asm`:

1. Stack e `Clock_EnterNormalSpeed` (la console parte a velocità normale).
2. `Lcd_Initialise`: LCD spento, font caricato, mappe azzerate.
3. `SramProbe_Run`: misura le banche e calcola il limite dei segnali.
4. Se SELECT è premuto: `SramDiagnostic_Run`.
5. `Application_Run` → `Storage_Mount`.

La WRAM non è inizializzata su hardware reale: nessuna routine deve presumere valori a zero all'avvio.

## 3. Memoria della console (WRAM)

| Zona | Dimensione | Proprietario |
|---|---|---|
| Stack | 64 byte | `main` |
| Specchio della directory | 779 byte | `storage` |
| Nome in modifica (`wNameBuffer`) | 11 byte | `name_buffer` |
| Nomi della lista a scorrimento | 32 × 11 = 352 byte | `list_view` |
| Buffer dei campioni (`$D000`–`$DEFF`) | 3840 byte | `sample_buffer` |

Il buffer dei campioni sta nella WRAM interna (`WRAMX`, banca 1). La cattura e l'invio IR leggono e scrivono solo questo buffer, mai la SRAM: la SRAM non regge gli accessi in double speed su alcune flashcart (ipotesi, vedi sezione 12).

## 4. SRAM della cartuccia

### 4.1 Header del ROM

`rgbfix -C` (solo GBC), tipo cartuccia `$1B` (MBC5 + RAM + batteria), ROM da 32 KB. La dimensione della RAM (`-r`) è la variabile `SRAM_SIZE_CODE` del Makefile: `0x04` = 128 KB (default), `0x03` = 32 KB, `0x02` = 8 KB.

MBC5: abilitazione RAM scrivendo `$0A` a `$0000`, selezione della banca (`$00`–`$0F`) scrivendo a `$4000` [R2]. Dimensioni della RAM nell'header (`$0149`): `$02` = 8 KiB, `$03` = 32 KiB, `$04` = 128 KiB [R3]. Il flag `$0143` segna il ROM come solo-GBC [R3]. `rgbfix` imposta questi byte [R8]. Il programma abilita la SRAM solo per il tempo di ogni accesso e la disabilita subito dopo.

### 4.2 Metà da 4096 byte

La SRAM si considera divisa in metà da 4096 byte (`$A000`–`$AFFF` e `$B000`–`$BFFF` di ogni banca).

- **Prima metà della banca 0:** directory.
- **Ogni altra metà:** un segnale. Il segnale `n` sta nella metà `n + 1`, cioè nella banca `(n + 1) / 2`, metà `(n + 1) % 2`.

Il numero massimo di segnali è `min(30, 2 × banche − 1)`, dove `banche` è il numero di banche distinte misurato all'avvio. Con 128 KB: 30. Con 32 KB: 7. Con 8 KB: 1.

### 4.3 Directory

Dimensione: 4 + 32 × 12 + 30 × 13 + 1 = **779 byte**.

| Offset | Lunghezza | Contenuto |
|---|---|---|
| 0 | 4 | firma `GBCR` (`47 42 43 52`) |
| 4 | 32 × 12 | voci delle schede |
| 388 | 30 × 13 | voci dei segnali |
| 778 | 1 | checksum |

Voce di scheda (12 byte): stato (`$A5` = usata, `$00` = libera) + 11 glifi di nome.
Voce di segnale (13 byte): stato + indice della scheda + 11 glifi di nome.

I nomi sono salvati come indici di glifo del font (A = 1, 0 = 27, spazio = 0), non come ASCII.

Checksum: `$C3` più la somma dei 778 byte precedenti, modulo 256.

**Due copie.** La directory è scritta due volte nella banca 0: la principale a `$A000` e una di riserva a `$A400`. Ogni scrittura riscrive entrambe e rilegge entrambe per verificarle.

**Montaggio** (`Storage_Mount`):

1. Legge la copia principale e la classifica: valida (firma e checksum giusti), non formattata (firma assente) o danneggiata (firma presente, checksum sbagliato).
2. Se valida: fine.
3. Altrimenti legge la copia di riserva. Se è valida, riscrive la principale e finisce in silenzio.
4. Se nessuna è valida: se almeno una ha la firma e contiene schede usate, riformatta e segnala E08. Se non contiene schede, riformatta in silenzio. Se nessuna ha la firma è il primo avvio: formatta in silenzio.

Stato **verificato** su emulatore (test `Test_Mount*`).

### 4.4 Campioni

Ogni metà di segnale contiene:

- 15 pagine da 256 byte = **3840 byte** di campioni;
- una sedicesima pagina riservata. Il suo ultimo byte (`base + $0FFF`) è la firma `$5A`.

Il segnale diventa "usato" nella directory solo dopo che i nomi sono confermati e la directory è scritta e riletta. Un nome annullato non lascia residui. Il campione, invece, è già scritto nella sua metà: resta come dato inutilizzato e viene sovrascritto alla prossima registrazione in quello slot.

La firma `$5A` serve a rilevare un campione mai scritto o danneggiato (errore E06).

### 4.5 Sonda della SRAM

A ogni avvio `SramProbe_Run` scrive un byte marcatore in `$AF00` di ciascuna delle 16 banche (indice della banca XOR `$6B`). `$AF00` sta nella pagina riservata della prima metà, quindi non è mai usato da directory o campioni.

Prima di scrivere, controlla se i marcatori dell'avvio precedente formano uno schema coerente (campo `SRAM KEPT`). Dopo aver scritto, ricava il numero di banche distinte `N`:

- Con `N` banche distinte, la banca `k` condivide la memoria con la banca `k mod N`. Dopo aver scritto le banche in ordine da 0 a 15, la banca fisica `j` contiene il marcatore della banca `16 − N + j`.
- Quindi `N = 16 − (indice letto nella banca 0)`, accettato solo se `N` è una potenza di due e tutte le 16 banche sono coerenti.
- Dalla `N` ricava il limite dei segnali, `2N − 1`, al massimo 30.

Il risultato compare nel menu della diagnostica e nelle schermate di E01 ed E08. **Verificato** su emulatore con SRAM da 8, 32 e 128 KB.

### 4.6 Diagnostica

SELECT premuto all'avvio apre il menu. Con A scrive in ogni banca un pattern (byte basso dell'indirizzo XOR `banca XOR $5C`) e lo rilegge subito. Dopo uno spegnimento, START rilegge lo stesso pattern. Il byte della sonda (`$AF00`) viene saltato. La diagnostica **cancella** tutti i dati salvati.

### 4.7 Il dubbio: i segnali finiscono tutti sulla stessa memoria?

**Il dubbio.** Il programma presume che la SRAM sia fatta di banche indipendenti da 8 KB: il registro a `$4000` sceglie quale banca appare in `$A000`–`$BFFF` [R2], e ogni segnale sta in una zona diversa. Ma l'header dichiara soltanto una dimensione [R3]; la flashcart può avere meno SRAM e ignorare i bit alti del registro di banca. In quel caso la banca `k` coincide con la banca `k mod N`, dove `N` è il numero di banche vere: tutte le banche puntano alla **stessa memoria fisica** ("una sola linea di memoria") e segnali e directory si scrivono l'uno sopra l'altro.

**Perché non si poteva escludere a priori.** Il codice scrive e rilegge subito, e la rilettura riesce comunque: il dato appena scritto è lì, anche se ha cancellato un altro. L'unico modo per saperlo è misurarlo. PyBoy ha sempre 128 KB distinti, quindi i test su emulatore non possono vederlo da soli.

**Effetto, per numero di banche vere:**

| Banche vere `N` | Memoria | Cosa succede | Segnali possibili |
|---|---|---|---|
| 16 | 128 KB | nessuna sovrapposizione | 30 |
| 8 | 64 KB | le banche 8–15 sono copie delle 0–7 | 15 |
| 4 | 32 KB | le banche 4–15 sono copie delle 0–3: un segnale oltre il settimo finirebbe sopra la directory e sugli altri | 7 |
| 1 | 8 KB | ogni banca è la stessa: restano solo due metà, la directory e un segnale | 1 |

**Cosa è successo davvero.** Con l'header a 128 KB la sonda ha risposto `ALIAS`. Con l'header a 32 KB ha misurato 4 banche. Prima di avere il limite, la cattura di un segnale in una banca "alta" scriveva 3840 byte sopra la directory in SRAM: la directory veniva riscritta solo se il nome veniva confermato, quindi un annullamento la lasciava danneggiata. È una delle cause probabili dei nomi sbagliati e dell'E08. Non è provata come causa unica: vedi la sezione 12.

**Come lo misuriamo** (sezione 4.5). All'avvio la sonda scrive un marcatore diverso in ogni banca e deduce `N` dallo schema che resta. Se lo schema non è coerente con nessun `N` (per esempio banche distinte solo in parte) assume `N = 1`, che è la scelta prudente.

**Cosa abbiamo fatto:**
- il numero massimo di segnali segue la SRAM trovata, `2 × N − 1`, al massimo 30;
- il segnale 0 usa la seconda metà della banca 0, che prima restava vuota;
- header selezionabile: `SRAM_SIZE_CODE` del Makefile, perché alcune flashcart decidono la SRAM dall'header [R3];
- due copie della directory e checksum (sezione 4.3);
- la misura è mostrata nel menu della diagnostica e sulle schermate E01 ed E08.

**Cosa resta aperto:**
- se la SRAM trovata diventa più piccola tra due avvii, i segnali oltre il nuovo limite non sono più raggiungibili: non c'è ancora un controllo;
- con `N = 1` entra un solo segnale;
- per recuperare capacità su una SRAM piccola servirebbe comprimere i segnali (sezione 13).

## 5. Campionamento infrarosso

### 5.1 Il registro RP (`$FF56`)

Vedi [R1], voce `FF56 — RP`.

| Bit | Funzione |
|---|---|
| 0 | scrittura: 1 = LED acceso |
| 1 | lettura: 0 = sensore illuminato |
| 6-7 | `11` abilita la lettura |

Il sensore non demodula: i campioni contengono già la portante a circa 38 kHz. Per questo la riproduzione non genera la portante, ma riproduce i campioni così come sono.

### 5.2 Formato

Un campione per bit, 8 campioni per byte, **1 = LED acceso**. Il primo campione finisce nel bit 0 del byte. In cattura il sensore viene invertito (`cpl` su ogni byte). In riproduzione `rr b` estrae prima il bit 0.

### 5.3 Temporizzazione

I conti sono in **cicli macchina** (M-cycle, 4 cicli di clock). Una stima precedente confondeva i due e sbagliava di un fattore 4.

| Velocità | Frequenza M-cycle | Durata M-cycle |
|---|---|---|
| normale | 1,048576 MHz | 0,954 µs |
| double speed | 2,097152 MHz | 0,477 µs |

I conteggi dei cicli delle istruzioni vengono dalla tabella di RGBDS [R7] (1 MHz, o 2 MHz in double speed).

Per campione: cattura = `ldh a,[c]` (2) + `rra` (1) + `rra` (1) + `rr b` (2) + `nop` (1) = **7**. Riproduzione = `rr b` (2) + `ld a,RP_...` (2) + `rla` (1) + `ldh [c],a` (2) = **7**.

Per byte: 8 × 7 + 9 di sovrappiù = **65**. Cattura: `ld a,b`, `cpl`, `ld [hli],a`, `ld a,h`, `cp e`, `jr nz` (4 + 5). Riproduzione: `ld a,[hli]`, `ld b,a`, `nop`, `ld a,h`, `cp e`, `jr nz` (4 + 5).

Risultati:
- campione ogni 7 M-cycle = **3,34 µs** in double speed (6,68 µs a velocità normale);
- 3840 byte × 65 M-cycle = 249 600 M-cycle = **119 ms** in double speed (238 ms a velocità normale);
- un frame NEC dura circa 67 ms: entra nei 119 ms;
- mezzo periodo della portante a 38 kHz: circa 13 µs, cioè circa 4 campioni: la risoluzione sposta ogni fronte di circa 3 µs. Un ricevitore poco tollerante potrebbe non riconoscere il segnale.

**Regola:** cattura e riproduzione devono avere la stessa cadenza. Chi modifica uno dei due cicli deve tenere uguale l'altro. Il `nop` in cattura e il `nop` per byte in riproduzione servono a questo.

### 5.4 Validazione

Dopo la cattura il programma conta i byte che cambiano rispetto al precedente. Con meno di 8 variazioni segnala E03 (disturbo, non un comando).

### 5.5 Storia

La prima versione campionava un byte per campione per circa 35 ms in double speed, meno di un frame NEC: la riproduzione non veniva riconosciuta. Con i campioni impacchettati e 119 ms la riproduzione funziona (**verificato su console**, prima delle schede).

## 6. Velocità della CPU

La console gira a velocità normale. Il double speed serve solo durante cattura e invio dell'IR.

- `Clock_EnterNormalSpeed`: torna a velocità normale se è in double speed.
- `Clock_EnterSignalSpeed`: porta alla velocità dell'IR, cioè `SELECTED_CPU_SPEED` (default double).

Cambio di velocità: `di`, tutte le righe del joypad deselezionate, `IF` e `IE` a zero, `KEY1 = 1`, `stop` [R1]. Dopo lo `stop` la CPU si ferma per 2050 M-cycle [R1], circa 2 ms a velocità normale. Le righe del joypad sono descritte in [R4].

Tutta la SRAM è usata a velocità normale. Il segnale viene catturato nel buffer in WRAM a double speed, poi copiato in SRAM a velocità normale.

## 7. Gestione degli errori

### 7.1 Meccanismo

Una routine che può fallire restituisce in `A` un codice, `0` per il successo. Le macro in `inc/error_handling.inc`:

- `Try routine`: chiama, e se `A` non è zero esce subito con lo stesso codice;
- `Throw codice`: carica il codice ed esce;
- `Succeed`: carica `ERROR_NONE` ed esce.

`Application_Catch` mostra l'errore a schermo come `ERROR E0n`, con il rimando a questo file (`SEE TECHNICAL.MD`). `ERROR_CANCELLED` (`$FF`) non è un errore: non viene mostrato e non ha codice.

### 7.2 Tabella degli errori

| Codice | Costante | Nome | Cosa significa | Cosa fare |
|---|---|---|---|---|
| E01 | `ERROR_STORAGE_VERIFY_FAILED` | Verifica memoria fallita | Il dato scritto in SRAM (directory o segnale), riletto, è diverso. La cartuccia non ha SRAM, la SRAM è disattivata o la scrittura non riesce. | Usa una cartuccia MBC5 con SRAM. Controlla le impostazioni di salvataggio della flashcart. |
| E02 | `ERROR_STORAGE_FULL` | Memoria piena | Tutti i posti per i segnali sono occupati (30 con 128 KB, meno con una SRAM più piccola). | Elimina un segnale con SELECT, poi registra di nuovo. |
| E03 | `ERROR_SIGNAL_TOO_SHORT` | Segnale troppo corto | Nel campione ci sono meno di 8 variazioni: è disturbo, non un comando. | Avvicina il telecomando al sensore. Evita sole e lampade a incandescenza. Riprova. |
| E04 | `ERROR_NAME_EMPTY` | Nome vuoto | Il nome è fatto solo di spazi. Con il nome completamente vuoto, START non dà errore: apre la conferma di annullamento. | Scrivi almeno un carattere diverso da spazio. |
| E05 | `ERROR_NAME_IN_USE` | Nome già in uso | Esiste già una scheda con quel nome (per una scheda), o un segnale con quel nome nella stessa scheda (per un segnale). | Scegli un nome diverso. |
| E06 | `ERROR_SIGNAL_DAMAGED` | Segnale danneggiato | Il campione salvato non ha la firma di integrità. | Elimina il segnale e registralo di nuovo. |
| E07 | `ERROR_INVALID_SLOT` | Indice non valido | Errore interno: indice di scheda o di segnale fuori intervallo. | Riavvia. Se si ripete, segnala il problema. |
| E08 | `ERROR_DIRECTORY_CORRUPT` | Directory danneggiata | Nessuna delle due copie della directory ha il checksum giusto, almeno una ha la firma e contiene schede. Il programma la riformatta e le schede vanno perse. Se la directory danneggiata era vuota, la riparazione è silenziosa. | Esegui la diagnostica SRAM (README) per capire se la flashcart conserva i dati. |
| E09 | `ERROR_CARD_LIST_FULL` | Troppe schede | Ci sono già 32 schede. | Elimina una scheda con SELECT, poi creane una nuova. |
| E10 | `ERROR_CARD_FULL` | Scheda piena | La scheda ha già 8 segnali. | Elimina un segnale della scheda o usa un'altra scheda. |

### 7.3 Le righe della SRAM su E01 ed E08

Sotto il codice, sulle schermate di E01 ed E08, il programma mostra due righe misurate all'avvio dalla sonda (sezione 4.5):

| Riga | Significato |
|---|---|
| `SRAM BANKS: 16/16` | Le 16 banche sono distinte: la SRAM è davvero da 128 KB. |
| `SRAM BANKS: 4/16` (o 1, 2, 8) | La SRAM è più piccola di 128 KB: le banche si sovrappongono (sezione 4.7). Il programma limita da solo i segnali alla memoria trovata. Prova anche la variante con l'header allineato (README). |
| `SRAM KEPT: YES` | I marcatori scritti all'avvio precedente c'erano ancora: la SRAM è stata conservata tra due avvii. |
| `SRAM KEPT: NO` | I marcatori non c'erano, o non formavano uno schema coerente: primo avvio, oppure la scheda ha ripristinato un vecchio salvataggio, oppure non ha mai salvato la SRAM. |

Con `KEPT: YES` e l'E08 che si ripete, il difetto non è nella conservazione della SRAM.

Le stesse due righe, `SRAM BANKS` e `SRAM KEPT`, compaiono nel menu della diagnostica (SELECT premuto all'avvio), senza bisogno di un errore.

## 8. Interfaccia

- **Testo:** font 5×7 in tessere 8×8, 46 glifi (maiuscole, cifre, `= ? . - : > ! _ /`). Le righe sono in 1 bit per pixel in ROM e vengono espanse a 2 bit al caricamento. Le stringhe usano un `CHARMAP` di RGBDS e finiscono con `$FF`.
- **Scrittura in VRAM:** solo a LCD spento o nel VBlank. Il cursore delle liste si aggiorna nel VBlank (meno di circa 1140 M-cycle disponibili); quando la lista scorre, la schermata si ridisegna a LCD spento.
- **Lista a scorrimento:** 14 righe visibili. La colonna del cursore appartiene alla lista: nessuna schermata deve scrivere lì.
- **Dialoghi:** un descrittore di 13 byte in ROM (domanda, riga di dettaglio, due avvisi, due righe di legenda, origine del nome da mostrare). `confirm_dialog` lo copia in WRAM e lo mostra. Una nuova conferma è un nuovo descrittore, non una nuova routine.
- **Tastiera:** 4 righe × 10 colonne. La riga dei numeri sta sopra le lettere (QWERTY). Il tasto spazio è l'ultimo.
- **Temi:** quattro palette (normale, ricezione, allarme, invio) scelte in `Theme_Apply`.
- **Contatore:** sulla lista delle schede, nella riga del titolo, `SIGNALS usati/limite`: i segnali in uso e il limite calcolato dalla SRAM trovata.

## 9. Audio

Canale 1 (onda quadra), registri `NR10`–`NR14`, controllo generale `NR50`–`NR52` [R5]. Melodia di successo: C5, E5, G5, C6. Melodia di eliminazione: G5, E5, C5, discendente. La durata si conta in frame (attesa del VBlank). I valori dei registri di frequenza (`2048 − 131072 / f`) sono in `inc/audio_notes.inc`.

## 10. Build

Serve RGBDS 1.0 o successivo.

| Comando | Risultato |
|---|---|
| `make` | `build/gbc-remote.gbc` |
| `make test` | build dei test ed esecuzione di tutta la suite |
| `make coverage` | esegue le suite con la misura della copertura e rigenera `docs/COVERAGE.md` e i badge |
| `make RGBDS_DIR=/percorso/` | usa RGBDS non nel `PATH` |
| `make BUILD_DIR=build/sram-32kb SRAM_SIZE_CODE=0x03` | variante con header a 32 KB |
| `make BUILD_DIR=build/sram-8kb SRAM_SIZE_CODE=0x02` | variante con header a 8 KB |
| `make CPU_SPEED=0 BUILD_DIR=...` | IR a velocità normale (solo per prova) |

## 11. Test

`make test` esegue due livelli, entrambi su PyBoy senza finestra.

**Unit test** (`tests/cases/`, 41) [R9]: una ROM di test linka le routine vere. Ogni test restituisce `0` se passa, altrimenti il numero dell'asserzione. Il runner (`tests/run_tests.py`) trova i test dal file `.sym`, esegue la ROM fino al marcatore di fine e legge i risultati dalla WRAM. Un test mai eseguito risulta fallito.

**Test di flusso** (`tests/run_flow_tests.py`, 14): avviano il ROM vero, premono i tasti e leggono la mappa dello sfondo. Il sensore IR è simulato con hook (`tests/flow_harness.py`):

- all'inizio di `Infrared_IsSignalDetected` forza "luce rilevata";
- in ognuna delle 8 copie del ciclo di cattura forza il valore letto;
- in ognuna delle 8 copie del ciclo di invio registra il livello scritto, per confrontare l'invio con la registrazione.

L'harness può anche preparare la SRAM prima dell'avvio (`ram_patches`) per simulare dati vecchi o danneggiati.

**Limiti della suite:** PyBoy non emula il sensore IR, non emula le flashcart e ha sempre 128 KB di SRAM distinti. Il rilevamento delle banche sovrapposte è provato con schemi sintetici e con header a 8 e 32 KB, non con una vera scheda.

Per aggiungere un test: una routine in `tests/cases/`, registrata in `tests/framework/test_table.asm` con `RegisterTest`. Per un flusso: una funzione `scenario_...` in `tests/run_flow_tests.py`, aggiunta a `SCENARIOS`.

## 12. Cosa abbiamo scoperto sull'hardware

Cronologia dei fatti, con il loro stato.

1. **Cattura troppo corta** (verificato su console). La prima cattura durava circa 35 ms: la riproduzione non veniva riconosciuta. Con i campioni impacchettati, 119 ms, la riproduzione funziona.
2. **Errore di unità** (corretto). Alcune stime iniziali contavano M-cycle come cicli di clock, sbagliando i tempi di un fattore 4. Ora tutto è in M-cycle.
3. **Salvataggio non conservato** (verificato su console). Dopo lo spegnimento comparivano nomi sbagliati ed E08.
4. **SRAM più piccola del dichiarato** (verificato su console). Con l'header a 128 KB la sonda ha risposto `ALIAS`: le banche si sovrapponevano. Con l'header a 32 KB: `SRAM BANKS: 04/16`, cioè 32 KB. Con le banche sovrapposte il programma sovrascriveva la propria directory.
5. **La scheda è un EverDrive GB** (verificato dai file). `GBOS.GB` ha nell'intestazione `KRKZ` (Krikzz). Il menu contiene `Load And Start`, `Load Only`, `RAM Size:`, `Save RAM:`, `Copy File To SRAM`, `Copy SRAM To File`, e i salvataggi vanno in `/EDGB/SAVE` come file `.srm`. Sulla scheda è scritto "EverDrive GB MAX"; il venditore la presenta come "Game Flash GB PRO (OS V4)". Non esiste un manuale.
6. **Il `.srm` estratto** (verificato) conteneva due schede ("1", "2") e un segnale ("QWERTY"), quindi la scheda salva davvero. Ma era un salvataggio vecchio: mancavano i marcatori della sonda scritti dalle versioni recenti. Il checksum calcolato era `0xF5` e quello salvato `0x75`: differenza `0x80`, un byte `0x80` nella voce del segnale 2 dove doveva esserci `0`. **Ignoto** se l'ha scritto il programma o un bit sbagliato della scheda.
7. **Ipotesi sul ciclo di E08** (non provata). `Load And Start` ricarica il `.srm` nella SRAM a ogni avvio. Se le scritture della sessione prima non sono mai state copiate nel `.srm`, il programma ritrova i dati vecchi. La procedura consigliata è copiare la SRAM nel file prima di rilanciare: vedi `README.md`.
8. **Dopo le due copie della directory e la procedura con il menu della scheda** (verificato su console) l'E08 non compare più. **Non sappiamo** se i dati restano davvero dopo lo spegnimento: da verificare.

Per rileggere il `.srm`: i primi 4 byte sono la firma, poi le voci come in 4.3. I file estratti sono in `../file-scheda/`.

## 13. Limiti e prossimi passi

- **Mai verificato su console:** il funzionamento completo delle schede e la persistenza dopo lo spegnimento.
- **Capacità bassa con 32 KB:** 7 segnali in totale. Una compressione dei segnali (durate di impulsi e pause più il periodo della portante, circa 150 byte invece di 3840) darebbe centinaia di segnali. La cattura resterebbe grezza e la riproduzione userebbe lo stesso ciclo: la compressione si farebbe a velocità normale dopo la cattura, e la decompressione prima dell'invio. Il rischio è nell'analisi di segnali reali e rumorosi.
- **Segnali oltre il limite:** se la SRAM trovata diventa più piccola tra due avvii, i segnali nelle metà oltre il limite non sono più raggiungibili. Non c'è ancora un controllo.
- **Misura della portante:** la frequenza non è misurata; senza analizzatore logico la temporizzazione si valida solo per simmetria e con le prove su console.
- **Metadati del campione:** il segnale non salva il periodo della portante né la velocità a cui è stato catturato.

## 14. Hardware usato per le prove

Elenco di tutto l'hardware su cui questo codice è stato provato. Va aggiornato ogni volta che si prova un nuovo dispositivo.

### Flashcart

| # | Dispositivo | Come identificato | Configurazioni provate | Esito |
|---|---|---|---|---|
| 1 | Flashcart venduta come "Game Flash GB PRO (Bitfunx), OS V4" [N1]. Sulla scheda è scritto "EverDrive GB MAX". | `GBOS.GB` ha nell'intestazione `KRKZ`: è il sistema EverDrive GB di Krikzz (sezione 12). | Header SRAM 128 KB: la sonda ha risposto `ALIAS`. Header SRAM 32 KB: 4 banche. | Registrazione, nome e riproduzione funzionano. Con le schede: nessun errore all'avvio. Conservazione dopo lo spegnimento: da verificare. |

Per ora c'è una sola flashcart. Nessun'altra scheda è stata provata.

### Altro hardware e strumenti

| Voce | Dettaglio |
|---|---|
| Console | Game Boy Color (modello non registrato) |
| Telecomando | non identificato (segnale di accensione) |
| microSD | contiene `/EDGB/SAVE/gbc-remote.srm` (32 KB) e la cartella `System Volume Information` (FAT). I file estratti sono in `../file-scheda/`. |
| Emulatore | PyBoy 2.9.0 [R9], Python 3.13.5, senza finestra |
| Assembler | RGBDS 1.0.4 [R6][R8] |
| Strumenti di misura | nessuno (niente analizzatore logico né oscilloscopio) |

## 15. Copertura dei test

`make coverage` esegue le due suite con un aggancio su ogni etichetta del codice e genera:

- `docs/COVERAGE.md`: percentuale totale, per suite, per modulo e l'elenco delle etichette non raggiunte;
- `docs/badges/*.svg`: i badge mostrati in testa al README (copertura delle etichette, unit test, test di flusso, piattaforma, stato dell'hardware).

**Cosa misura.** Un'etichetta (routine o punto di diramazione) conta come coperta se il programma ci arriva almeno una volta durante i test. È una copertura approssimata dei blocchi di codice, **non** di riga e non dei valori dei dati.

**Cosa esclude.** Le tabelle in `src/data/`, l'intestazione del ROM e tutto il codice di test.

**Limiti.**
- Misura quello che i test eseguono su emulatore, non quello che gira su console.
- I punti raggiunti solo dai simulatori del sensore IR sono contati come coperti quando l'aggancio del simulatore scatta.
- Una percentuale alta non dimostra che i test controllino abbastanza: indica solo che il codice viene eseguito.
- Al momento della scrittura l'unica etichetta non raggiunta è `Storage_Mount.reformatFailed`: richiede che la scrittura in SRAM fallisca durante la riformattazione, e l'emulatore non lo fa. L'elenco aggiornato è in `docs/COVERAGE.md`.
- Il dettaglio dell'aggancio: l'etichetta si aggancia con `hook_register` di PyBoy [R9] e l'aggancio viene tolto dopo il primo passaggio. La rimozione avviene dopo ogni avanzamento dell'emulatore, non dentro la funzione di aggancio, perché lì PyBoy segnala un errore e rallenta l'esecuzione di molto.

## 16. Riferimenti

Fonti ufficiali, consultate il 15/11/2026 (pagina aperta e contenuto controllato):

- **[R1]** Pan Docs, *CGB Registers*: `KEY1` (`$FF4D`, cambio di velocità, la CPU si ferma 2050 M-cycle dopo `stop`) e `RP` (`$FF56`, porta a infrarossi). <https://gbdev.io/pandocs/CGB_Registers.html>
- **[R2]** Pan Docs, *MBC5*: abilitazione RAM `$0000`–`$1FFF` (`$0A`), numero di banca RAM `$4000`–`$5FFF` (`$00`–`$0F`). <https://gbdev.io/pandocs/MBC5.html>
- **[R3]** Pan Docs, *The Cartridge Header*: flag CGB `$0143`, tipo `$0147`, dimensione ROM `$0148`, dimensione RAM `$0149`. <https://gbdev.io/pandocs/The_Cartridge_Header.html>
- **[R4]** Pan Docs, *Joypad Input*: registro `P1/JOYP` (`$FF00`). <https://gbdev.io/pandocs/Joypad_Input.html>
- **[R5]** Pan Docs, *Audio Registers*: `NR10`–`NR14`, `NR50`–`NR52`. <https://gbdev.io/pandocs/Audio_Registers.html>
- **[R6]** RGBDS, *rgbasm(5)*: linguaggio assembly (`CHARMAP`, `MACRO`, `FOR`, sezioni). <https://rgbds.gbdev.io/docs/v1.0.4/rgbasm.5>
- **[R7]** RGBDS, *gbz80(7)*: riferimento delle istruzioni con i cicli. <https://rgbds.gbdev.io/docs/v1.0.4/gbz80.7>
- **[R8]** RGBDS, *rgbfix(1)*: opzioni `-C`, `-m`, `-r`, `-t`. <https://rgbds.gbdev.io/docs/v1.0.4/rgbfix.1>
- **[R9]** PyBoy, documentazione e sorgenti (versione 2.9.0). <https://docs.pyboy.dk/> e <https://github.com/Baekalfen/PyBoy>
- **[R10]** RGBDS, rilasci: <https://github.com/gbdev/rgbds/releases>

Fonti non ufficiali (venditori e forum), viste come risultati di ricerca e **non controllate in dettaglio**. Non esiste un manuale della scheda usata; quanto segue è indicativo:

- **[N1]** Handheld Legend, *Game Flash GB PRO (Bitfunx)*: <https://handheldlegend.com/products/game-flash-gb-pro-bitfunx>
- **[N2]** Retro Game Repair Shop, *Game Flash GB Pro Plus*: <https://retrogamerepairshop.com/products/game-flash-gb-pro-plus>
- **[N3]** PicClick, annuncio *Game Flash GB PRO*: <https://picclick.com/Jeu-Flash-GB-PRO-Bitfunx-286054184684.html>
- **[N4]** Retromodding, *Krikzz EverDrive GB X7*: <https://www.retromodding.com/collections/vendors/products/krikzz-everdrive-gb-x7>
- **[N5]** Stone Age Gamer, *EverDrive GB X7*: <https://stoneagegamer.com/everdrive-gb-x7-base.html>
- **[N6]** r/everdrive, *how to save state with GB X7* (copia su un mirror): <https://redlib.belloworld.it/r/everdrive/comments/1g9b2n9/how_to_save_state_with_gb_x7>

Cose dedotte da file: il menu del sistema `GBOS.GB` (voci `Load And Start`, `Copy SRAM To File`, percorso `/EDGB/SAVE`) viene dall'analisi delle stringhe del file estratto dalla scheda, non da un manuale.
