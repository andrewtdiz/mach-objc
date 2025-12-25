# Bun FFI Architecture

## Directory Structure

```
bunffi/
├── core/                  # Engine primitives (input, commands, scheduler)
├── engine/                # Engine lifecycle, FFI loader, symbols
├── editor/                # Editor application layer
│   ├── project/
│   │   ├── store.ts       # Project state + dirty tracking
│   │   ├── watcher.ts     # File change detection
│   │   └── schema.ts      # Project JSON types
│   ├── actions/           # Editor commands (drag, property edit, etc.)
│   └── index.ts           # Editor entry point
└── index.ts               # Engine-only entry point (testing/dev)
```

## Runtime Model

Single Bun process. Editor imports engine modules directly - no IPC, shared memory space, same FFI handle to Zig.

```
bun run bunffi/editor/index.ts
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│                    BUN RUNTIME                          │
├─────────────────────────────────────────────────────────┤
│  editor/              │  core/ + engine/                │
│  - Project state      │  - FFI bindings                 │
│  - File I/O           │  - Input handling               │
│  - Actions            │  - Command encoding             │
│                       │  - Frame scheduler              │
└───────────────────────┴─────────────────────────────────┘
                        │ FFI
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    ZIG (src/)                           │
│  - Window management                                    │
│  - WebGPU rendering                                     │
│  - Input polling                                        │
│  - Mesh/UI command execution                            │
└─────────────────────────────────────────────────────────┘
```

## Project File Persistence

File I/O stays in Bun. Zig handles rendering only.

### Read Flow (file watcher)
```
project.json changes → Bun.watch detects → parse JSON → update ProjectStore → sync to Zig via FFI
```

### Write Flow (debounced)
```
Editor action → mutate ProjectStore → markDirty() → debounce timer → Bun.write(project.json)
```

### ProjectStore (module state)
```ts
let projectData: SceneGraph | null = null;
let filePath: string = "";
let dirty = false;
let writeTimer: Timer | null = null;

function load(path: string): void { ... }
function save(): void { ... }
function markDirty(): void { ... }
function getData(): SceneGraph { ... }
```

### File Watcher
```ts
const watcher = Bun.watch(projectPath, (event) => {
  if (event === "change") {
    projectData = JSON.parse(Bun.file(projectPath).text());
    syncToEngine();
  }
});
```

### Debounced Write
```ts
function markDirty() {
  dirty = true;
  if (!writeTimer) {
    writeTimer = setTimeout(() => {
      Bun.write(filePath, JSON.stringify(projectData));
      dirty = false;
      writeTimer = null;
    }, 150);
  }
}
```

## Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                           EDITOR                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐   │
│  │ File Watch  │───▶│ ProjectStore│───▶│ Actions (drag, etc) │   │
│  └─────────────┘    └─────────────┘    └─────────────────────┘   │
│         ▲                  │                      │              │
│         │                  │ markDirty()          │              │
│         │                  ▼                      │              │
│  ┌─────────────┐    ┌─────────────┐               │              │
│  │ project.json│◀───│ Write Queue │               │              │
│  └─────────────┘    └─────────────┘               │              │
└──────────────────────────────────────────────────────────────────┘
                                                    │
                                                    │ FFI calls
                                                    ▼
┌──────────────────────────────────────────────────────────────────┐
│                           ENGINE                                 │
│  createMesh / setMeshPosition / setMeshColor / commitUICommands  │
└──────────────────────────────────────────────────────────────────┘
```

## Separation of Concerns

| Layer | Responsibility | File I/O |
|-------|---------------|----------|
| editor/ | Project state, persistence, user actions | Yes |
| core/ | Input, commands, scheduling | No |
| engine/ | FFI bindings, lifecycle | No |
| src/ (Zig) | Rendering, GPU, window | No |
