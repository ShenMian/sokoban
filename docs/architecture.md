# Architecture

This document describes the high-level architecture of the project.

## Technology Stack

```mermaid
flowchart LR
    FRONT["`**Godot**<br>(Frontend)`"]
    BRIDGE["`**GDExtension**<br>(Bridge)`"]
    BACK["`**Rust**<br>(Backend)`"]
    DB[("`**SQLite**<br>(Database)`")]

    FRONT <-->|Calls /<br>Signals| BRIDGE
    BRIDGE <-->|Calls /<br>Signals| BACK
    BRIDGE -->|Reads / Writes| DB
```

## Scenes

```mermaid
flowchart LR
    LEVEL_LIST["Level List"]
    GAMEPLAY["Gameplay"]
    PAUSE_MENU["Pause Menu"]
    SETTINGS_MENU["Settings Menu"]
    CREDITS["Credits"]
    VICTORY_MENU["Victory Menu"]
    SOLVER_PANEL["Solver Panel"]

    LEVEL_LIST <--> GAMEPLAY
    GAMEPLAY --> PAUSE_MENU
    PAUSE_MENU <--> SETTINGS_MENU
    PAUSE_MENU <--> CREDITS
    GAMEPLAY --> VICTORY_MENU
    GAMEPLAY <--> SOLVER_PANEL
```

## Database

| Table Name            | Description                                                                   |
| --------------------- | ----------------------------------------------------------------------------- |
| `tb_collection`       | Stores information about level collections                                    |
| `tb_level`            | Stores level information                                                      |
| `tb_collection_level` | Stores many-to-many relationships between collections and levels              |
| `tb_solution`         | Saves the player's solutions for a level (move/push optimal ones are flagged) |
| `tb_snapshot`         | Saves snapshots of level progress (auto/manual save)                          |

```mermaid
erDiagram
    tb_collection {
        INTEGER id PK "AUTOINCREMENT"
        TEXT name UK "NOT NULL"
        TEXT description
        DATETIME datetime "NOT NULL, DEFAULT CURRENT_TIMESTAMP"
    }

    tb_level {
        INTEGER id PK "AUTOINCREMENT"
        TEXT map_xsb "NOT NULL"
        TEXT title
        TEXT author
        TEXT comments
        INTEGER hash UK "NOT NULL, hash of the canonicalized map"
        DATETIME datetime "NOT NULL, DEFAULT CURRENT_TIMESTAMP"
    }

    tb_collection_level {
        INTEGER collection_id PK, FK "ON DELETE CASCADE"
        INTEGER level_id PK, FK "ON DELETE CASCADE"
        INTEGER idx
    }

    tb_solution {
        INTEGER level_id PK, FK "ON DELETE CASCADE"
        TEXT actions_lurd PK
        BOOLEAN move_optimal "NOT NULL"
        BOOLEAN push_optimal "NOT NULL"
        DATETIME datetime "NOT NULL, DEFAULT CURRENT_TIMESTAMP"
    }

    tb_snapshot {
        INTEGER id PK "AUTOINCREMENT"
        INTEGER level_id FK "ON DELETE CASCADE"
        TEXT actions_lurd
        BOOLEAN autosave "NOT NULL"
        DATETIME datetime "NOT NULL, DEFAULT CURRENT_TIMESTAMP"
    }

    tb_collection ||--o{ tb_collection_level : "has"
    tb_level ||--o{ tb_collection_level : "has"
    tb_level ||--o{ tb_solution : "has solutions"
    tb_level ||--o{ tb_snapshot : "has snapshots"
```
