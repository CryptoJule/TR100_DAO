# Rocket100 DAO - Dezentrales Voting-System mit Token-Locking

## Übersicht

Rocket100 DAO ist ein dezentrales Abstimmungssystem auf der Aptos-Blockchain, das einen fortschrittlichen Token-Locking-Mechanismus implementiert. Das System ermöglicht Inhabern von RocketOneHundred (TR100) Tokens, an Governance-Entscheidungen teilzunehmen, indem sie Tokens in einen Smart Contract einzahlen und damit abstimmen. Im Gegensatz zu einfacheren Systemen werden die Tokens physisch in einem Escrow gehalten, was die Sicherheit und Integrität des Abstimmungsprozesses erheblich verbessert.

## Architektur

Das System besteht aus drei Hauptkomponenten:

1. **TR100 Token** - Der existierende RocketOneHundred Token auf der Aptos-Blockchain, der als Stimmrecht-Token dient.

2. **Token-Escrow-Modul** (`tr100_token_escrow.move`) - Verwaltet die sichere Verwahrung von Tokens während des Lockings.

3. **Token-Locker-Modul** (`tr100_token_locker.move`) - Implementiert die Logik für das Sperren und Entsperren von Tokens.

4. **DAO-Voting-Modul** (`tr100_dao_voting.move`) - Verwaltet den Abstimmungsprozess, einschließlich Erstellung, Stimmabgabe und Ergebnisermittlung.

## Hauptfunktionen

### Token-Locking mit Escrow

- Tokens werden physisch in einen Smart Contract übertragen, nicht nur logisch markiert
- Verhindert die Verwendung gesperrter Tokens für andere Zwecke
- Automatische Freigabe von Tokens nach Abschluss der Abstimmung

### Governance-Abstimmungen

- Erstellung von zeitlich begrenzten Abstimmungen durch den DAO-Deployer
- Ja/Nein-Abstimmungen mit festgelegten Start- und Endzeiten
- Stimmgewichtung basierend auf der Anzahl gesperrter Tokens (1 Token = 1 Stimme)
- Verhinderung von Mehrfachabstimmungen durch denselben Nutzer

### Transparenz und Überprüfbarkeit

- Öffentliche View-Funktionen zur Abfrage des Abstimmungsstatus
- Ereignisprotokollierung für alle wichtigen Aktionen
- On-chain Nachverfolgung von Abstimmungshistorien

## Technische Details

### Module und Ressourcen

**Token-Escrow-Modul:**
- Verwaltet die `TokenEscrow<CoinType>` Ressource, die gesperrte Tokens sicher aufbewahrt
- Implementiert Ein- und Auszahlungsmechanismen mit entsprechenden Ereignissen
- Bietet View-Funktionen zur Überprüfung von Einzahlungen

**Token-Locker-Modul:**
- Verwaltet den `UserLockStatus<CoinType>` für jeden Benutzer
- Koordiniert die Interaktion zwischen Benutzern und dem Escrow-System
- Bietet Funktionen zur Reservierung und Freigabe von Tokens für Abstimmungen

**DAO-Voting-Modul:**
- Definiert die `Poll` und `DAOVoting` Ressourcen zur Verwaltung von Abstimmungen
- Implementiert Abstimmungsmechanismen mit Tokengewichtung
- Stellt View-Funktionen für Abstimmungsstatus und -ergebnisse bereit

### Sicherheitsaspekte

- **Physisches Token-Locking:** Verhindert Doppelausgaben und Manipulation durch physische Übertragung der Tokens in den Escrow
- **Berechtigungskontrolle:** Kritische Funktionen (z.B. Erstellung von Abstimmungen) sind auf den DAO-Deployer beschränkt
- **Status- und Fehlerprüfungen:** Umfassende Prüfungen zur Vermeidung ungültiger Zustände
- **Typensicherheit:** Verwendung von generischen Typparametern für sichere Token-Interaktionen

## Installation und Setup

### Voraussetzungen

- Aptos CLI (neueste Version)
- Ein Aptos-Konto mit ausreichend APT für Transaktionsgebühren
- RocketOneHundred (TR100) Tokens für die Teilnahme

### Installation

1. Klone das Repository:
```bash
git clone https://github.com/user/rocket100-dao.git
cd rocket100-dao
```

2. Konfiguriere dein Aptos-Profil:
```bash
aptos init --profile rocket_dao
```

3. Kompiliere das Projekt:
```bash
aptos move compile
```

4. Veröffentliche die Module:
```bash
aptos move publish --profile rocket_dao --max-gas 150000 --named-addresses rocket100_dao=0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166,rocket_token=0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989
```

5. Initialisiere den Token-Escrow:
```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_token_locker::initialize_token_escrow --type-args 0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989::rocket_one_hundred::ROCKETONEHUNDRED
```

6. Initialisiere das DAO-Voting-System (falls noch nicht geschehen):
```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::initialize
```

## Nutzungsanleitung

### Tokens sperren

Um Tokens zu sperren und Stimmrechte zu erwerben:

```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_token_locker::lock_tokens_entry --type-args 0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989::rocket_one_hundred::ROCKETONEHUNDRED --args u64:1000
```

### Gesperrte Tokens überprüfen

Überprüfe, wie viele Tokens du gesperrt hast:

```bash
aptos move view --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_token_locker::get_locked_tokens --type-args 0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989::rocket_one_hundred::ROCKETONEHUNDRED --args address:DEINE_ADRESSE
```

### Abstimmung erstellen (nur für DAO-Deployer)

Erstelle eine neue Abstimmung mit 24-Stunden-Laufzeit:

```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::create_poll_entry --args "string:Neue DAO Abstimmung" u64:$(date +%s) u64:$(($(date +%s) + 86400))
```

Um eine längere Abstimmungsdauer festzulegen, ändere einfach den Zeitwert im Befehl. Zum Beispiel:

### 3 Tage (259.200 Sekunden)
```
bashaptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::create_poll_entry --args "string:Dreitägige Abstimmung" u64:$(date +%s) u64:$(($(date +%s) + 259200))
```
### 1 Woche (604.800 Sekunden):
```
bashaptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::create_poll_entry --args "string:Wöchentliche Abstimmung" u64:$(date +%s) u64:$(($(date +%s) + 604800))
```
### 1 Monat (ca. 2.592.000 Sekunden):
```
bashaptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::create_poll_entry --args "string:Monatliche Abstimmung" u64:$(date +%s) u64:$(($(date +%s) + 2592000))
```
### An einer Abstimmung teilnehmen

Stimme für Option 1 (Ja) bei Abstimmung mit ID 1:

```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::vote_entry --type-args 0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989::rocket_one_hundred::ROCKETONEHUNDRED --args u64:1 u8:1
```

### Abstimmungsstatus überprüfen

Den Status einer Abstimmung abrufen:

```bash
aptos move view --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::get_poll_status --args u64:1
```

Die Rückgabe ist ein Tupel mit folgenden Werten:
- `is_started` (bool): Ob die Abstimmung begonnen hat
- `is_active` (bool): Ob die Abstimmung aktiv ist
- `start_time` (u64): Startzeitpunkt der Abstimmung
- `end_time` (u64): Endzeitpunkt der Abstimmung
- `votes_option_0` (u64): Anzahl der Stimmen für Option 0 (Nein)
- `votes_option_1` (u64): Anzahl der Stimmen für Option 1 (Ja)

### Abstimmung beenden

Nach Ablauf der Abstimmungszeit:

```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::check_and_end_poll_entry --type-args 0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989::rocket_one_hundred::ROCKETONEHUNDRED --args u64:1
```

### Abstimmungsergebnis abrufen

Nach Ende der Abstimmung:

```bash
aptos move view --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_dao_voting::get_poll_result --args u64:1
```

Die Rückgabe ist ein Tupel mit folgenden Werten:
- `is_ended` (bool): Ob die Abstimmung beendet ist
- `votes_option_0` (u64): Anzahl der Stimmen für Option 0 (Nein)
- `votes_option_1` (u64): Anzahl der Stimmen für Option 1 (Ja)
- `winner` (u8): Gewinner der Abstimmung (0 für Option 0, 1 für Option 1, 2 für Unentschieden)

### Tokens entsperren

Nach Ende der Abstimmung können Tokens entsperrt werden:

```bash
aptos move run --profile rocket_dao --function-id 0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166::tr100_token_locker::unlock_tokens_entry --type-args 0x543d8eee91b4cca80c8878db5a37497efd73a56ac516a936dccfbed7d14ff989::rocket_one_hundred::ROCKETONEHUNDRED --args u64:1000
```

## Sicherheitsüberlegungen

Das Rocket100 DAO-System implementiert mehrere Sicherheitsmaßnahmen:

1. **Physischer Escrow-Mechanismus**: Tokens werden tatsächlich aus der Wallet des Benutzers in den Smart Contract übertragen, was die Sicherheit erheblich verbessert im Vergleich zu rein logischem Locking.

2. **Saubere Berechtigungstrennung**: Nur der DAO-Deployer kann bestimmte administrative Aktionen wie die Erstellung von Abstimmungen durchführen.

3. **Umfassende Fehlerbehandlung**: Alle Funktionen enthalten strenge Prüfungen, um ungültige Zustände zu vermeiden.

4. **Transparente Event-Emission**: Wichtige Aktionen werden als Events emittiert, was die Nachverfolgbarkeit und Transparenz erhöht.

5. **Move's Ressourcenmodell**: Nutzt das sichere Ressourcenmodell von Move, das lineare Typen implementiert und somit viele übliche Smart-Contract-Schwachstellen ausschließt.

## Fehlerbehebung

### Häufige Probleme

1. **Abstimmungsfehler "E_ALREADY_VOTED"**: Der Benutzer hat bereits an dieser Abstimmung teilgenommen. Jede Wallet kann nur einmal pro Abstimmung abstimmen.

2. **Fehler "INSUFFICIENT_BALANCE_FOR_TRANSACTION_FEE"**: Nicht genügend APT für Transaktionsgebühren. Füge deiner Wallet mehr APT hinzu.

3. **Fehler "E_INSUFFICIENT_TOKENS"**: Nicht genügend TR100-Tokens zum Sperren. Überprüfe dein Token-Guthaben.

4. **Fehler beim Entsperren "E_TOKENS_LOCKED_IN_VOTE"**: Tokens können nicht entsperrt werden, da sie in einer aktiven Abstimmung verwendet werden. Warte, bis die Abstimmung endet und rufe dann `check_and_end_poll_entry` auf.

### Debugging-Tools

- `aptos move run-view`: Zum Aufrufen von View-Funktionen, die den aktuellen Zustand des DAO zeigen
- Aptos Explorer (https://explorer.aptoslabs.com/): Zum Überprüfen von Transaktionen, Events und Ressourcen auf der Blockchain
- `aptos move test`: Zum Ausführen von Unit-Tests für deine Module (falls implementiert)

## Zukünftige Erweiterungen

Das Rocket100 DAO-System könnte in Zukunft um folgende Funktionen erweitert werden:

1. **Mehrfache Abstimmungsoptionen**: Unterstützung für mehr als nur Ja/Nein-Abstimmungen
2. **Delegiertes Voting**: Erlaubt die Delegation von Stimmrecht an andere Benutzer
3. **Gewichtete Abstimmungen**: Differenzierte Stimmgewichtung basierend auf Token-Menge und Sperrzeit
4. **On-Chain-Ausführung**: Automatische Ausführung von Code basierend auf Abstimmungsergebnissen
5. **Benutzerfreundliche Frontend-Integration**: Entwicklung einer Web-App zur einfacheren Interaktion mit dem DAO
6. **Multi-Token-Unterstützung**: Erweiterung des Systems für verschiedene Token-Typen

## Lizenz und Mitwirkende

Dieses Projekt steht unter der MIT-Lizenz. Mitwirkende:
- Ursprüngliche Implementierung: Cloud.AI
- Escrow-Erweiterung: CloudAI-Rocket100 Team

## Support und Community

Bei Fragen oder Problemen wende dich an:
- GitHub Issues: [github.com/user/rocket100-dao/issues](https://github.com/user/rocket100-dao/issues)
- Discord-Server: [discord.gg/rocket100dao](https://discord.gg/rocket100dao)

---

*Rocket100 DAO - Sichere Token-basierte Governance auf Aptos*