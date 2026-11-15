# GBC-remote

![label coverage](docs/badges/coverage.svg) ![unit tests](docs/badges/unit-tests.svg) ![flow tests](docs/badges/flow-tests.svg) ![platform](docs/badges/platform.svg) ![hardware tests](docs/badges/hardware.svg)

I badge sono generati da `make coverage`. Il dettaglio della copertura è in [`docs/COVERAGE.md`](docs/COVERAGE.md).

Usa il Game Boy Color come telecomando a infrarossi. Registri i segnali IR dei tuoi telecomandi, li raggruppi in schede (televisione, radio, aria condizionata, ...), restano salvati nella SRAM della cartuccia e li riproduci quando vuoi.

## Requisiti hardware

- Un Game Boy Color con finestra IR. Il GBA non ha IR, nemmeno in modalità GBC.
- Una cartuccia o flashcart MBC5 con SRAM salvabile. Le registrazioni vivono nella SRAM, non nella RAM. Più SRAM c'è, più segnali entrano: 30 con 128 KB, 7 con 32 KB, 1 con 8 KB.
- Il ROM è solo GBC (`rgbfix -C`): su un DMG non parte.

## Come si usa

Al **primo avvio**, senza nessuna scheda, il programma entra subito in ricezione. Punta il telecomando verso il Game Boy e premi un suo tasto. A segnale acquisito il programma chiede **prima il nome della scheda, poi il nome del segnale**. Il segnale viene salvato nella scheda appena creata e ti ritrovi nella lista delle schede.

La prima schermata è sempre la lista delle schede, e non è mai vuota: finché non esiste nessuna scheda, ogni annullamento, errore o scarto riporta alla ricezione. Lo stesso vale se elimini l'ultima scheda.

| Schermata | Tasto | Azione |
|---|---|---|
| Lista schede | Su / Giù | Sceglie la scheda (la lista scorre) |
| Lista schede | **A** | Apre la scheda e mostra i suoi segnali |
| Lista schede | **START = New** | Crea una scheda: chiede il nome, la scheda nasce vuota |
| Lista schede | **SELECT = Del** | Elimina la scheda, con due conferme |
| Lista segnali | Su / Giù | Sceglie il segnale |
| Lista segnali | **A = OK** | Invia il segnale selezionato |
| Lista segnali | **START = New** | Registra un nuovo segnale nella scheda: ricezione, poi nome |
| Lista segnali | **SELECT = Del** | Chiede conferma ed elimina il segnale |
| Lista segnali | **B = Back** | Torna alla lista delle schede |
| Ricezione | **B = Back** | Annulla l'attesa. Se non ci sono schede, la ricezione riparte |
| Tastiera | Croce direzionale | Muove il cursore |
| Tastiera | A | Inserisce il carattere |
| Tastiera | **B = Back** | Cancella l'ultimo carattere. A nome vuoto scarta tutto e torna indietro |
| Tastiera | START | Salva con il nome scritto. A nome vuoto chiede conferma di annullamento |
| Conferma annullamento | **A = YES** | Scarta e torna indietro (alla ricezione se non ci sono schede) |
| Conferma annullamento | **B = NO** | Torna alla tastiera |
| Eliminazione segnale | **A = YES / B = NO** | Elimina / annulla |
| Eliminazione scheda, primo avviso | **A = CONTINUE / B = CANCEL** | Prosegue / annulla |
| Eliminazione scheda, seconda conferma | **A = YES / B = NO** | Elimina la scheda e tutti i suoi segnali / annulla |
| Errore | A | Chiude la schermata |

In ogni schermata una piccola legenda in basso riepiloga i tasti disponibili.

**Eliminare una scheda:** compaiono due avvisi consecutivi, in inglese. Il primo avverte che eliminando la scheda si perdono anche tutti i suoi segnali. Il secondo chiede una seconda conferma. La scheda sparisce solo se confermi entrambi.

**Scheda vuota:** una scheda senza segnali resta nella lista. Dentro vedi `EMPTY CARD` e START aggiunge un segnale.

**Nomi:**
- Massimo 11 caratteri, sia per le schede sia per i segnali.
- Caratteri disponibili: `A-Z`, `0-9`, `-`, `.`, `:` e spazio. La tastiera è QWERTY, con la riga dei numeri sopra le lettere.
- Almeno un carattere diverso da spazio (E04 per un nome di soli spazi).
- I nomi delle schede sono unici tra le schede. I nomi dei segnali sono unici dentro la loro scheda (E05 se già usato).

**Suoni:** una breve melodia a registrazione riuscita, un'altra breve melodia (discendente) quando elimini un segnale o una scheda.

**Capacità:** al massimo 32 schede e 8 segnali per scheda. Il totale dei segnali dipende dalla SRAM della scheda, che il programma misura a ogni avvio: `2 × banche − 1`, al massimo 30. Con 128 KB (16 banche) sono 30 segnali, con 32 KB (4 banche) sono 7, con 8 KB (1 banca) è 1. I segnali di tutte le schede condividono la stessa riserva. Il numero di banche trovate è mostrato come `SRAM BANKS: NN/16` nel menu della diagnostica SRAM e nelle schermate E01 ed E08.

Le regole di progetto (comportamento richiesto, convenzioni, verifica) sono in `../AGENTS.md`.

## Errori

Gli errori mostrano `ERROR E0n` a schermo (e, per i nomi, sotto il campo del nome), con il rimando `SEE TECHNICAL.MD`. L'annullamento con B non è un errore e non mostra nessun codice.

La **tabella dei codici**, con il significato e cosa fare, è in [`docs/TECHNICAL.md`](docs/TECHNICAL.md), sezione 7. Sulle schermate di E01 ed E08 compaiono anche due righe sulla SRAM (`SRAM BANKS`, `SRAM KEPT`): la loro spiegazione è nella sezione 7.3.

## Dal codice alla console

Il **solo file che serve sulla console è il ROM `build/gbc-remote.gbc`** (o la variante in `build/sram-32kb/`). Non servono `.sym`, `.map`, `.o`, i test o il venv: sono file di sviluppo. Il salvataggio lo crea la flashcart, non devi portarlo tu.

I menu e le impostazioni cambiano da flashcart a flashcart: per quei passi vale il manuale del produttore. Questa procedura è stata verificata in parte su una scheda EverDrive GB (vedi "Cosa abbiamo scoperto").

### Cosa serve

- Un PC con Linux, macOS o Windows, `make` e RGBDS 1.0 o successivo.
- Una flashcart per Game Boy Color con mapper MBC5 e SRAM salvabile, e la sua microSD.
- Un Game Boy Color. Il GBA non ha l'IR, il DMG non avvia ROM solo-GBC.
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

L'ultimo comando deve stampare `rgbasm v1.0.4` (o più recente). Su macOS e Windows scarica l'archivio della stessa release dalla pagina [RGBDS](https://github.com/gbdev/rgbds/releases) e metti `rgbasm`, `rgblink` e `rgbfix` nel `PATH`. Senza `sudo` puoi lasciare RGBDS dove l'hai estratto e passare il percorso a `make`.

### 2. Compilare il ROM

Dalla cartella `GBC-remote/`:

```
make
```

Se RGBDS non è nel `PATH`: `make RGBDS_DIR=/percorso/di/rgbds/` (con la barra finale). Il risultato è `build/gbc-remote.gbc`, 32 KB, con l'header a 128 KB di SRAM.

Il programma misura da solo la SRAM che trova e adatta la capacità, ma alcune flashcart decidono la SRAM dall'header. Se la tua ha meno di 128 KB, prova la variante con l'header allineato:

| SRAM | Comando | ROM |
|---|---|---|
| 128 KB (default) | `make` | `build/gbc-remote.gbc` |
| 32 KB | `make BUILD_DIR=build/sram-32kb SRAM_SIZE_CODE=0x03` | `build/sram-32kb/gbc-remote.gbc` |
| 8 KB | `make BUILD_DIR=build/sram-8kb SRAM_SIZE_CODE=0x02` | `build/sram-8kb/gbc-remote.gbc` |

Facoltativo: `make test` (vedi la sezione Test).

### 3. Preparare la microSD

1. Formatta la microSD come richiede la flashcart (di solito FAT32).
2. Copia il ROM sulla scheda, nella cartella dei giochi.
3. Espelli la microSD in modo sicuro e rimettila nella flashcart.

### 4. Accendere e usare

1. Con la console **spenta**, inserisci la flashcart.
2. Accendi il Game Boy Color e scegli `GBCREMOTE` dal menu della flashcart.
3. Al primo avvio vedi `WAITING FOR SIGNAL`. Punta il telecomando verso la finestra IR (bordo superiore del Game Boy Color), a pochi centimetri, e premi un suo tasto.
4. Scrivi il nome della scheda e premi START, poi il nome del segnale e di nuovo START. Senti la melodia di conferma e vedi la lista delle schede.
5. Apri la scheda con A. Nella lista dei segnali, A invia il segnale: punta il Game Boy verso il dispositivo da comandare.

Sulla lista delle schede, in alto, `SIGNALS 03/30` indica quanti segnali sono in uso e il massimo permesso dalla SRAM trovata.

### 5. Salvare i dati con una scheda EverDrive GB

Se la tua flashcart usa il sistema EverDrive GB di Krikzz (la schermata del menu o il file `GBOS.GB` lo dicono), il menu ha, premendo B sul gioco scelto, queste voci: `Load And Start`, `Load Only`, `RAM Size:`, `Save RAM:`, `Copy File To SRAM`, `Copy SRAM To File`. I salvataggi sono file `.srm` in `/EDGB/SAVE` sulla microSD.

Procedura consigliata (le voci sono dedotte dai testi del sistema, non da un manuale):

1. Sul gioco scelto premi B e imposta `RAM Size` come l'header del ROM (32K per la variante a 32 KB) e `Save RAM` attivo.
2. Avvia con `Load And Start`, usa il programma, **aspetta almeno 3 secondi** e spegni.
3. Alla riaccensione, nel menu, scegli `GBCREMOTE`, premi B e **`Copy SRAM To File`**: copia la SRAM trattenuta dalla scheda nel `.srm`.
4. Poi `Load And Start`.

Se salti il punto 3, `Load And Start` ricarica il vecchio `.srm` e i dati nuovi si perdono. Per ripartire da zero, cancella `/EDGB/SAVE/gbc-remote.srm`.

### 6. Se qualcosa non va

- **Schermo nero:** controlla che sia un Game Boy Color, non un DMG.
- **`ERROR E01`:** la scrittura in SRAM non viene riletta uguale: la flashcart non ha SRAM o ha la SRAM disattivata.
- **`ERROR E03` a ogni registrazione:** segnale troppo corto. Avvicina il telecomando ed evita sole e lampade a incandescenza.
- **`ERROR E08`:** la directory era danneggiata e conteneva schede, e viene riformattata. Le righe `SRAM BANKS` e `SRAM KEPT` sotto il codice dicono com'è la SRAM (vedi `docs/TECHNICAL.md`, sezione 7.3). Vedi anche il punto 5.
- **I dati spariscono dopo lo spegnimento:** controlla il punto 5. Per sapere quanta SRAM c'è e se si conserva, usa la diagnostica.
- **Il segnale registrato non fa nulla quando lo invii:** registra con il telecomando vicino. L'IR usa il double speed (default): non cambiarlo.
- **Pochi segnali:** il limite dipende dalla SRAM della scheda (`SIGNALS 03/07` significa 7 posti).

### Diagnostica SRAM

Mostra quante banche di SRAM ci sono e se si conservano dopo lo spegnimento.

**Vedere solo la capacità** (senza cancellare nulla): tieni premuto **SELECT** mentre avvii il ROM. Nel menu leggi `SRAM BANKS: NN/16` (le banche distinte) e `SRAM KEPT: YES/NO`. Premi **B** per uscire.

**Provare la conservazione dei dati** (cancella tutti i comandi salvati):

1. SELECT premuto all'avvio, poi **A**: scrive un pattern in ciascuna delle 16 banche e lo rilegge. Vedi `BANK 00 OK` ... `BANK 15 OK`.
2. Spegni, riaccendi tenendo premuto SELECT, premi **START** per verificare lo stesso pattern.
3. **B** per uscire. Il programma riparte da zero.

| Risultato | Significato |
|---|---|
| Tutte OK dopo A e dopo START | La SRAM funziona e si conserva. |
| BAD già dopo A su alcune banche | La SRAM ha meno di 16 banche distinte. È normale con 32 KB o 8 KB: quelle banche sono sovrapposte. |
| OK dopo A, BAD dopo START | La flashcart non conserva (o non ripristina) la SRAM tra gli avvii. |

## Cosa abbiamo scoperto

Riassunto di quello che abbiamo imparato sull'hardware. I dettagli, le cifre e lo stato di ogni fatto sono in [`docs/TECHNICAL.md`](docs/TECHNICAL.md).

- **Il segnale IR serve lungo almeno un frame intero.** La prima versione registrava solo 35 ms e il comando non veniva riconosciuto. Ora registra 119 ms e la riproduzione funziona su console.
- **La SRAM della scheda è più piccola del previsto.** Con l'header a 128 KB le banche si sovrapponevano, cioè i segnali finivano sulla stessa memoria e il programma sovrascriveva i propri dati. La scheda usata ha 32 KB (4 banche), cioè 7 segnali. Il dubbio e come lo misuriamo sono spiegati nella sezione 4.7 di `docs/TECHNICAL.md`.
- **La scheda è una EverDrive GB di Krikzz.** Salva in `/EDGB/SAVE/*.srm`, ma solo con le sue regole (menu del file, `Copy SRAM To File`).
- **Il salvataggio estratto era vecchio e aveva un bit sbagliato** nella directory. Per questo ora la directory ha due copie e un controllo, e un solo bit sbagliato viene riparato da solo.
- **Non sappiamo ancora se i dati restano dopo lo spegnimento** con la procedura del punto 5: va provato.

## Hardware usato per le prove

Finora è stata provata **una sola flashcart**: una scheda venduta come "Game Flash GB PRO (Bitfunx), OS V4", con scritto "EverDrive GB MAX" sulla scheda e il sistema EverDrive GB di Krikzz. Con l'header a 128 KB la SRAM risulta sovrapposta, con l'header a 32 KB risultano 4 banche. L'elenco completo (console, emulatore, strumenti, esiti) è in `docs/TECHNICAL.md`, sezione 14.

## Test

```
python3 -m venv .venv
.venv/bin/pip install -r tests/requirements.txt
make test
make coverage
```

La suite ha 41 unit test (ROM di test con le routine vere) e 14 scenari di flusso (il ROM vero con tasti premuti e schermo letto), entrambi su emulatore PyBoy senza finestra. L'IR è simulato. `make coverage` misura quante etichette del codice vengono raggiunte dai test e rigenera i badge in testa a questo file. I dettagli sono in `docs/TECHNICAL.md`.

## Documentazione tecnica

Tutta la parte tecnica è in [`docs/TECHNICAL.md`](docs/TECHNICAL.md):

- architettura e moduli;
- formato della directory, checksum, due copie e ripristino;
- disposizione della SRAM, due segnali per banca, sonda e diagnostica;
- campionamento IR e temporizzazione in cicli macchina;
- velocità della CPU e gestione degli errori;
- interfaccia, audio, build e varianti;
- test e harness di flusso;
- cronologia di quello che abbiamo scoperto sull'hardware, con lo stato di ogni fatto;
- limiti e prossimi passi (compressione dei segnali);
- hardware usato per le prove, copertura dei test e riferimenti a documentazioni tecniche (Pan Docs, RGBDS, PyBoy).

Le regole di sviluppo sono in `../AGENTS.md`.

## Stato

Le schede sono implementate e i 41 unit test e 14 scenari di flusso passano su emulatore. Su console reale, prima delle schede, funzionavano registrazione, nome e riproduzione. Con le schede: nessun errore all'avvio, ma la persistenza dopo lo spegnimento non è ancora verificata.
