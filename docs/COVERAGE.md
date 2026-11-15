# Copertura dei test

Generato da `make coverage`. Non modificare a mano.

La copertura è misurata sulle **etichette** del codice (routine e punti di diramazione) raggiunte almeno una volta durante la suite di test su emulatore. Non è una copertura di riga e non misura i valori dei dati.

| Misura | Etichette | Percentuale |
|---|---|---|
| Totale | 312 / 313 | 99.7% |
| Solo unit test | 123 / 313 | 39.3% |
| Solo test di flusso | 307 / 313 | 98.1% |

## Per modulo

| Modulo (sezione) | Etichette coperte | Percentuale |
|---|---|---|
| AcquireScreen | 1 / 1 | 100.0% |
| Application | 12 / 12 | 100.0% |
| Audio | 3 / 3 | 100.0% |
| CardListScreen | 9 / 9 | 100.0% |
| Clock | 3 / 3 | 100.0% |
| ConfirmDialog | 14 / 14 | 100.0% |
| ErrorHandling | 2 / 2 | 100.0% |
| ErrorScreen | 4 / 4 | 100.0% |
| Infrared | 28 / 28 | 100.0% |
| Jingle | 6 / 6 | 100.0% |
| Joypad | 1 / 1 | 100.0% |
| Keyboard | 17 / 17 | 100.0% |
| Lcd | 9 / 9 | 100.0% |
| ListView | 21 / 21 | 100.0% |
| Main | 1 / 1 | 100.0% |
| Memory | 8 / 8 | 100.0% |
| NameBuffer | 6 / 6 | 100.0% |
| NameEntryScreen | 15 / 15 | 100.0% |
| Screen | 2 / 2 | 100.0% |
| SignalCapture | 3 / 3 | 100.0% |
| SignalListScreen | 11 / 11 | 100.0% |
| Sram | 3 / 3 | 100.0% |
| SramDiagnostic | 24 / 24 | 100.0% |
| SramProbe | 12 / 12 | 100.0% |
| Storage | 82 / 83 | 98.8% |
| Theme | 2 / 2 | 100.0% |
| VramText | 7 / 7 | 100.0% |
| WorkflowCard | 2 / 2 | 100.0% |
| WorkflowDelete | 1 / 1 | 100.0% |
| WorkflowRecord | 2 / 2 | 100.0% |
| WorkflowSend | 1 / 1 | 100.0% |

## Etichette non raggiunte

| Modulo | Etichetta |
|---|---|
| Storage | `Storage_Mount.reformatFailed` |
