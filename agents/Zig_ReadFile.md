# Reading Files in Zig with `std.Io.Reader`

This guide covers modern, idiomatic ways to read files in Zig using the `std.Io.Reader` interface.

## Core Concepts

- **`std.fs.File.reader()`**: This method on a `std.fs.File` object returns a `std.fs.File.Reader`, which provides the `std.Io.Reader` interface for reading from the file. It does not take a buffer as an argument.
- **`std.Io.Reader`**: A standard interface for any type that can be read from. It has methods like `read`, `readAllAlloc`, and `readUntilDelimiterOrEof`.
- **Memory**: You are responsible for providing buffers for the reader to read into. This can be done by allocating memory with an `Allocator` or by using a fixed-size buffer on the stack.

---

## Method 1: Reading the Entire File

This is the simplest method for files you know will fit into memory.

**Requires**: An `std.mem.Allocator`.

### Pattern:

```zig
const std = @import("std");

fn readFileToBuffer(allocator: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
    // 1. Open the file
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    // 2. Get the reader
    var reader = file.reader();

    // 3. Allocate a buffer and read the whole file into it
    const data = try reader.readAllAlloc(allocator, max_size);
    return data;
}
```

- **`readAllAlloc`**: Reads from the reader until EOF and returns a newly allocated slice containing the data.
- **`max_size`**: A safety limit to prevent allocating too much memory.

---

## Method 2: Streaming Line-by-Line

This is the most memory-efficient method for reading text files, especially large ones. It reads the file in chunks (lines) without loading the entire file.

**Requires**: A temporary, fixed-size buffer on the stack.

### Pattern:

```zig
const std = @import("std");

fn processFileByLine(path: []const u8) !void {
    // 1. Open the file
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    // 2. Get the reader
    var reader = file.reader();

    // 3. Create a buffer on the stack to hold line data
    var buffer: [1024]u8 = undefined;

    // 4. Loop, reading until the ''
''' delimiter
    while (try reader.readUntilDelimiterOrEof(&buffer, ''
''')) |line| {
        // The `line` slice points into `buffer`.
        // It does not include the ''
''' delimiter.
        // `null` is returned at EOF, which terminates the while loop.
        std.debug.print("Line: {s}
", .{line});
    }
}
```

- **`readUntilDelimiterOrEof`**: Reads into the provided `buffer` until it finds the delimiter or hits the end of the stream. It returns `?[]u8`, which is `null` at EOF.