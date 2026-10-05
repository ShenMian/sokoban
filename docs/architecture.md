# Architecture

This document describes the high-level architecture of the project.

## Technology Stack

```mermaid
flowchart LR
    FRONT["`**Godot**<br>(Frontend)`"]
    BRIDGE["`**GDExtension**<br>(Bridge)`"]
    BACK["`**Rust**<br>(Backend)`"]

    FRONT -->|Calls function /<br>Emits signal| BRIDGE
    BRIDGE -->|Calls functions| BACK
    BACK -->|Returns results| BRIDGE
    BRIDGE -->|Returns results /<br>Emits signals| FRONT
```

## Scenes

```mermaid
flowchart LR
    LEVEL_LIST["Level List"]
    GAMEPLAY["Gameplay"]
    PAUSE_MENU["Pause Menu"]
    SETTINGS_MENU["Settings Menu"]
    VICTORY_MENU["Victory Menu"]

    LEVEL_LIST <--> GAMEPLAY
    GAMEPLAY --> PAUSE_MENU
    PAUSE_MENU <--> SETTINGS_MENU
    GAMEPLAY --> VICTORY_MENU
```

## Database

| Table Name            | Description                                                                          |
| --------------------- | ------------------------------------------------------------------------------------ |
| `tb_collection`       | Stores information about level collections                                           |
| `tb_level`            | Stores level information                                                             |
| `tb_collection_level` | Stores many-to-many relationships between collections and levels                     |
| `tb_solution`         | Saves the player's complete solution for a level (move/push optimal and non-optimal) |
| `tb_snapshot`         | Saves snapshots of level progress (auto/manual save)                                 |

```mermaid
erDiagram
    tb_collection {
        INTEGER id PK "AUTOINCREMENT"
        TEXT name UK "NOT NULL"
        TEXT description
        DATETIME datetime "DEFAULT CURRENT_TIMESTAMP"
    }

    tb_level {
        INTEGER id PK "AUTOINCREMENT"
        TEXT map_xsb "NOT NULL"
        TEXT title
        TEXT author
        TEXT comments
        INTEGER hash UK "NOT NULL"
        DATETIME datetime "DEFAULT CURRENT_TIMESTAMP"
    }

    tb_collection_level {
        INTEGER collection_id FK "NOT NULL"
        INTEGER level_id FK "NOT NULL"
        INTEGER idx
    }

    tb_solution {
        INTEGER level_id FK "NOT NULL"
        TEXT actions_lurd "NOT NULL"
        BOOLEAN move_optimal "NOT NULL"
        BOOLEAN push_optimal "NOT NULL"
        DATETIME datetime "DEFAULT CURRENT_TIMESTAMP"
    }

    tb_snapshot {
        INTEGER id PK "AUTOINCREMENT"
        INTEGER level_id FK "NOT NULL"
        TEXT actions_lurd
        BOOLEAN autosave "NOT NULL"
        DATETIME datetime "DEFAULT CURRENT_TIMESTAMP"
    }

    tb_collection ||--o{ tb_collection_level : "has"
    tb_level ||--o{ tb_collection_level : "has"
    tb_level ||--o{ tb_solution : "has solutions"
    tb_level ||--o{ tb_snapshot : "has snapshots"
```
