# GBC-remote

Usa il Game Boy Color come telecomando a infrarossi. Registra un segnale IR, gli dai un nome, resta salvato nella SRAM della cartuccia e lo puoi riprodurre quando vuoi.

## Requisiti hardware

- Un Game Boy Color con finestra IR. Il GBA non ha IR, nemmeno in modalità GBC.
- Una cartuccia o flashcart MBC5 con **128 KB di SRAM con batteria**. Le registrazioni vivono in SRAM, non in RAM.
- Il ROM è solo GBC (`rgbfix -C`): su un DMG non parte.

## Come si usa

Al **primo avvio** il programma entra subito in ricezione. Punta il telecomando verso il Game Boy e premi un suo tasto. A segnale acquisito scrivi il nome con la tastiera virtuale e salva.

La lista non è mai vuota: finché non esiste almeno un comando salvato, ogni annullamento, errore o scarto riporta alla ricezione. Lo stesso vale se elimini l'ultimo comando.

| Schermata | Tasto | Azione |
|---|---|---|
| Lista | Su / Giù | Sceglie il comando |
| Lista | **A = OK** | Invia il segnale selezionato |
| Lista | **START = New** | Nuova registrazione, poi scelta del nome |
| Lista | **SELECT = Del** | Chiede conferma ed elimina il comando |
| Ricezione | **B = Back** | Annulla l'attesa e torna alla lista. Se non ci sono comandi, la ricezione riparte |
| Tastiera | Croce direzionale | Muove il cursore |
| Tastiera | A | Inserisce il carattere |
| Tastiera | **B = Back** | Cancella l'ultimo carattere. A nome vuoto scarta il segnale e torna alla lista (o alla ricezione, se non ci sono comandi) |
| Tastiera | START | Salva con il nome scritto. A nome vuoto chiede conferma di annullamento |
| Conferma annullamento | **A = YES** | Scarta il segnale e torna alla lista (o alla ricezione, se non ci sono comandi) |
| Conferma annullamento | **B = NO** | Torna alla tastiera |
| Conferma eliminazione | **A = OK** | Elimina |
| Conferma eliminazione | **B = Back** | Annulla |
| Errore | A | Chiude la schermata |

In ogni schermata una piccola legenda in basso riepiloga i tasti disponibili.

Regole sui nomi: massimo 8 caratteri (`A-Z`, `0-9`, `-`, `.`, `:`, spazio), almeno un carattere diverso da spazio, **unici**. Un nome già usato è rifiutato con E05. Un nome fatto solo di spazi è rifiutato con E04.

Quando una registrazione va a buon fine, lo speaker suona una breve melodia.

Capacità: 8 comandi.

Le regole di progetto (comportamento richiesto, convenzioni, verifica) sono in `../AGENTS.md`.

## Errori

Gli errori mostrano `ERROR E0n` (a schermo e, per i nomi, sotto il campo del nome). Il codice rimanda a questa tabella.

| Codice | Nome | Cosa significa | Cosa fare |
|---|---|---|---|
| E01 | Verifica memoria fallita | Il dato scritto in SRAM, riletto, è diverso. La cartuccia non ha SRAM, la batteria è esaurita o il salvataggio è disattivato. | Usa una cartuccia MBC5 con 128 KB di SRAM. Controlla le impostazioni di salvataggio della flashcart. |
| E02 | Memoria piena | Tutti gli 8 slot sono occupati. | Elimina un comando con SELECT, poi registra di nuovo. |
| E03 | Segnale troppo corto | Nel campione ci sono meno di 8 variazioni: è disturbo, non un comando. | Avvicina il telecomando al sensore. Evita sole e lampade a incandescenza. Riprova. |
| E04 | Nome vuoto | Il nome è fatto solo di spazi. Con il nome completamente vuoto, START non dà errore: apre la conferma di annullamento. | Scrivi almeno un carattere diverso da spazio. |
| E05 | Nome già in uso | Esiste già un comando con quel nome. | Scegli un nome diverso. |
| E06 | Segnale danneggiato | Il campione salvato non ha la firma di integrità. | Elimina il comando e registralo di nuovo. |
| E07 | Slot non valido | Errore interno: indice di slot fuori intervallo. | Riavvia. Se si ripete, segnala il problema. |
| E08 | Directory danneggiata | La firma c'è, ma il checksum della directory non torna: la SRAM è tornata diversa da come era stata scritta. Il programma la riformatta. L'errore compare solo se la directory danneggiata conteneva comandi (che vanno persi): se era vuota, la riparazione è silenziosa. | Esegui la diagnostica SRAM (sezione sotto) per capire se la flashcart conserva i dati. |

L'annullamento con B non è un errore e non mostra nessun codice.

Come funziona il "try/catch": ogni routine che può fallire restituisce in `A` un codice (`0` = ok). La macro `Try` interrompe la routine e propaga il codice a chi l'ha chiamata. `Application_Catch` mostra la schermata d'errore. Vedi `inc/error_handling.inc`.

## Dal codice alla console

Il **solo file che serve sulla console è il ROM `build/gbc-remote.gbc`**. Non servono `.sym`, `.map`, `.o`, i test o il venv: sono tutti file di sviluppo. Il salvataggio (`.sav`) lo crea la flashcart, non devi portarlo tu.

Questa procedura non è stata verificata su hardware reale: i menu e le impostazioni cambiano da flashcart a flashcart, quindi per quei passi vale il manuale del produttore.

### Cosa serve

- Un PC con Linux, macOS o Windows, `make` e RGBDS 1.0 o successivo.
- Una flashcart per Game Boy Color con **mapper MBC5 e 128 KB di SRAM salvabile** e la sua scheda microSD. Verifica sul manuale del produttore che la tua flashcart supporti MBC5 con 128 KB di SRAM: non ho potuto controllare nessun modello.
- Un Game Boy Color. Il GBA e il DMG non vanno bene: il GBA non ha l'IR, il DMG non avvia ROM solo-GBC.
- Un telecomando IR da registrare.

### 1. Installare RGBDS

Su Linux:

```
curl -L -O https://github.com/gbdev/rgbds/releases/download/v1.0.4/rgbds-linux-x86_64.tar.xz
mkdir rgbds
tar -xJf rgbds-linux-x86_64.tar.xz -C rgbds
cd rgbds
sudo ./install.sh
rgbasm --version
```

L'ultimo comando deve stampare `rgbasm v1.0.4` (o più recente). Su macOS e Windows scarica l'archivio della stessa release dalla pagina [RGBDS](https://github.com/gbdev/rgbds/releases) e metti `rgbasm`, `rgblink` e `rgbfix` nel `PATH`.

Senza `sudo` puoi lasciare RGBDS dove l'hai estratto e passare il percorso a `make` (punto 2).

### 2. Compilare il ROM

Dalla cartella `GBC-remote/`:

```
make
```

Se RGBDS non è nel `PATH`: `make RGBDS_DIR=/percorso/di/rgbds/` (con la barra finale).

Il risultato è `build/gbc-remote.gbc`, 32 KB. L'header dichiara: solo GBC, MBC5 con RAM e batteria, 128 KB di SRAM. Se `make` fallisce, controlla di avere RGBDS 1.0 o successivo.

Facoltativo, prima di copiare il ROM: `make test` (vedi la sezione Test).

### 3. Preparare la microSD

1. Inserisci la microSD nel PC.
2. Formattala come richiede la flashcart (di solito FAT32).
3. Copia `build/gbc-remote.gbc` sulla scheda, nella cartella dei giochi.
4. Espelli la scheda in modo sicuro e rimettila nella flashcart.

### 4. Impostare la flashcart

Con ROM e header corretti molte flashcart configurano mapper e salvataggio da sole. Se la tua chiede i valori a mano, imposta:

- Mapper: **MBC5**.
- Salvataggio: **SRAM 128 KB**, abilitato.

Alcune flashcart scrivono il salvataggio sulla microSD solo allo spegnimento o con un comando dedicato: leggi il manuale. Se il salvataggio non viene scritto, i comandi registrati spariscono al riavvio.

### 5. Accendere e usare

1. Con la console **spenta**, inserisci la flashcart nello slot.
2. Accendi il Game Boy Color e scegli `GBCREMOTE` dal menu della flashcart.
3. Al **primo avvio** vedi la schermata `WAITING FOR SIGNAL`.
4. Punta il telecomando verso la finestra IR, sul bordo superiore del Game Boy Color, a pochi centimetri, e premi un suo tasto.
5. Scrivi il nome con la tastiera virtuale e premi START. Senti la melodia di conferma e vedi la lista.
6. Dalla lista, A invia il segnale selezionato: punta il Game Boy verso il dispositivo da comandare.

Dal secondo avvio in poi parti direttamente dalla lista.

### 6. Se qualcosa non va

- **Schermo nero o la flashcart non lo carica:** controlla che sia un Game Boy Color, non un DMG o un GBA.
- **`ERROR E01` al primo avvio:** la flashcart non offre SRAM. Imposta MBC5 e SRAM 128 KB.
- **`ERROR E03` a ogni registrazione:** segnale troppo corto. Avvicina il telecomando, evita sole e lampade a incandescenza.
- **Dopo il riavvio i nomi hanno caratteri sbagliati o compare E08:** la SRAM non è tornata uguale. Esegui la diagnostica SRAM (sezione sotto) e confronta il risultato con la tabella.
- **I comandi spariscono al riavvio:** il programma scrive i comandi nella SRAM della cartuccia (la ROM è di sola lettura e non si può usare). Se dopo lo spegnimento non ci sono più, la flashcart non ha scritto la SRAM sulla microSD. Controlla il punto 4 e il manuale: alcune flashcart salvano solo con un comando dedicato o tornando al menu.
- **Il segnale registrato non fa nulla quando lo invii:** usa la velocità `CPU_SPEED_DOUBLE` (default). A velocità normale il campionamento è troppo lento per la portante a 38 kHz. Registra con il telecomando vicino al sensore e riprova. Vedi anche i limiti noti.
- Gli altri codici sono nella tabella Errori.

### Velocità e SRAM

La console gira a **velocità normale**. Directory, salvataggio, lettura e verifica della SRAM avvengono solo a velocità normale, perché alcune flashcart non reggono gli accessi alla SRAM in double speed. Il double speed si usa solo durante la cattura e l'invio dell'IR, che hanno bisogno del campionamento a 3,3 µs. Il segnale viene catturato in un buffer in WRAM e copiato in SRAM dopo il ritorno a velocità normale.

Per provare tutto a velocità normale (l'IR campiona male, serve solo per prova): `make BUILD_DIR=build/normal-speed CPU_SPEED=0`.

### Diagnostica SRAM

Serve a capire se la flashcart conserva la SRAM tra uno spegnimento e l'altro. **Cancella tutti i comandi salvati.**

1. Tieni premuto **SELECT** mentre avvii il ROM, finché compare `SRAM TEST`.
2. Premi **A**: il programma scrive un pattern diverso in ciascuna delle 9 banche e lo rilegge subito. Vedi `BANK 00 OK` ... `BANK 08 OK`.
3. Spegni la console e riaccendila, tenendo premuto SELECT. Premi **START** per verificare lo stesso pattern.
4. Premi **B** per uscire. Il programma riparte da zero.

| Risultato | Significato |
|---|---|
| Tutte OK al punto 2 e al punto 3 | La SRAM funziona e viene conservata. Il problema è altrove: segnalami i dettagli. |
| BAD già al punto 2 su alcune banche | La flashcart ha meno di 128 KB di SRAM: le banche si sovrappongono. Riduci `SLOT_COUNT` e l'header (`-r`) alla SRAM disponibile. |
| OK al punto 2, BAD al punto 3 | La flashcart non conserva (o non ripristina) la SRAM tra gli avvii. Controlla il manuale: salvataggio su microSD, momento in cui viene scritto. |

### Salvataggi

I comandi stanno in un file `.sav` da 128 KB creato dalla flashcart, di solito accanto al ROM o in una cartella dedicata. Copialo sul PC per farne un backup. Per ripartire da zero cancella il `.sav`: al riavvio il programma formatta la memoria e torna al primo avvio.

## Test

```
python3 -m venv .venv
.venv/bin/pip install -r tests/requirements.txt
make test
```

La suite ha due livelli, entrambi headless su emulatore PyBoy:

- **Unit test** (`tests/cases/`, 33 test): ROM di test con le routine reali. Coprono gestione errori, buffer del nome, cursore della tastiera, directory e SRAM, validazione del segnale. Il runner (`tests/run_tests.py`) legge i risultati dalla WRAM tramite il file `.sym`. Un test mai eseguito conta come fallito.
- **Test di flusso** (`tests/run_flow_tests.py`, 8 scenari): avviano il ROM vero, premono i tasti e leggono lo schermo. Simulano il sensore IR con hook sui loop di cattura (`tests/flow_harness.py`). Verificano primo avvio, ripartenza della ricezione senza comandi (annullamento, scarto, eliminazione dell'ultimo), errore E03, nome duplicato (E05), nome di soli spazi (E04), conferma di annullamento con nome vuoto (sì e no), conferma di eliminazione (sì e no), persistenza dopo riavvio, che il segnale riprodotto sia uguale a quello registrato, e la diagnostica SRAM con spegnimento e riaccensione.

## Configurazione

- Velocità dell'IR: `SELECTED_CPU_SPEED` in `inc/application_config.inc`. Valori `CPU_SPEED_NORMAL` (4,19 MHz) o `CPU_SPEED_DOUBLE` (8,39 MHz). Vale solo per cattura e invio dell'IR: tutto il resto gira a velocità normale. Il Game Boy Color offre solo queste due velocità: l'overclock oltre il double speed richiede una modifica hardware.
- Numero di slot: `SLOT_COUNT` (default 8). Le banche SRAM usate sono `SLOT_COUNT + 1`.

## Come è salvato

SRAM, 16 banche da 8 KB (header `rgbfix -r 0x04`):

- Banca 0: directory. Firma `GBCR`, 8 voci da 9 byte (stato `$A5` = usata, poi 8 glifi di nome) e un byte di checksum, 77 byte in tutto. Se la firma manca, la directory viene formattata: questo è il "primo avvio". Se la firma c'è ma il checksum non torna, la directory viene riformattata e appare E08.
- Banche 1-8: un campione IR per slot. I campioni sono impacchettati a 8 per byte (un bit per campione, 1 = LED acceso), 4096 byte per slot. L'ultimo byte della banca (`$BFFF`) è la firma `$5A`.

La registrazione scrive direttamente nella banca dello slot libero. Lo slot diventa "usato" solo quando il nome è confermato, quindi un nome annullato non lascia residui.

## Limiti noti

- **Mai provato su hardware reale.** IR, temporizzazione e double speed sono verificati solo su emulatore. Su PyBoy il sensore è simulato con hook, non emulato.
- Un campione ogni 7 cicli macchina: circa 3,3 µs in double speed, circa 6,7 µs a velocità normale. Una registrazione dura circa 127 ms in double speed (254 ms a velocità normale) e copre un frame NEC completo (circa 67 ms). Per l'IR resta il double speed: a velocità normale il campionamento è troppo grossolano per una portante a 38 kHz (mezzo periodo circa 13 µs).
- Una versione precedente campionava un byte per campione, per circa 35 ms in double speed. Era meno della durata di un comando NEC e la riproduzione poteva non essere riconosciuta. Se anche ora la riproduzione non funziona, la causa va cercata nell'hardware (LED troppo debole, distanza, temporizzazione) e serve una misura con un analizzatore logico.
- La frequenza della portante non è misurata: i campioni contengono già gli impulsi modulati e il replay li riproduce così come sono. Con 3,3 µs di risoluzione ogni fronte della portante può spostarsi di circa 3 µs su 13 µs di mezzo periodo: un ricevitore poco tollerante può non riconoscere il segnale.

## Struttura

```
inc/            costanti, registri, macro (nessun numero magico nel codice)
src/boot/       punto di ingresso e main
src/hal/        registri hardware: clock, lcd, joypad, sram, infrared, audio, testo
src/lib/        funzioni di memoria
src/logic/      storage, nome, tastiera, schermate (lista, nome, errore),
                dialoghi (elimina, annulla), workflow (registra, invia, elimina),
                cattura del segnale, melodia, gestione errori
src/data/       font, stringhe, palette, tastiera, melodia, firma directory
tests/          framework asm, casi, runner Python, harness di flusso
```

## Stato

Verificato su hardware reale solo in parte: la registrazione e il nome funzionano, la riproduzione funziona. Dopo il riavvio la lista torna, ma i nomi risultano sbagliati: causa non ancora accertata (vedi la diagnostica SRAM). Le prove su emulatore passano: 33 unit test e 8 scenari di flusso.
