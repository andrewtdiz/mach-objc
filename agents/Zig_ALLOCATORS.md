# 3  Memory and Allocators

In this chapter, we will talk about memory. How does Zig control memory? What common tools are used? Are there any important aspects that make memory different/special in Zig? You will find the answers here.

Computers fundamentally rely on memory to function. This memory acts as a temporary storage space for the data and values generated during computations. Without memory, the core concepts of “variables” and “objects” in programming languages would be impossible.

## 3.1  Memory spaces

Every object that you create in your Zig source code needs to be stored somewhere, in your computer’s memory. Depending on where and how you define your object, Zig will use a different “memory space”, or a different type of memory to store this object.

Each type of memory normally serves for different purposes. In Zig, there are 3 types of memory (or 3 different memory spaces) that we care about. They are:

- Global data register (or the “global data section”)
- Stack
- Heap

### 3.1.1  Compile-time known versus runtime known

One strategy that Zig uses to decide where it will store each object that you declare is by looking at the value of this particular object—more specifically, by investigating if this value is known at **compile time** or at **runtime**.

When you write a program in Zig, the values of some of the objects you write are known at compile time. Meaning that, when you compile your Zig source code, the compiler can figure out the exact value of a particular object that exists in your source code. Knowing the length (or the size) of each object is also important, and in some cases it’s known at compile time.

The Zig compiler cares more about knowing the **size** of a particular object than its actual value. If the compiler knows the value, it automatically knows the size, because it can calculate it from the value.

Therefore, the priority for the Zig compiler is to discover the size of each object. If the value of the object is known at compile time, then the compiler automatically knows the size. If the value is not known at compile time, then the size is only known at compile time if, and only if, the type of this object has a known fixed size.

For a type to have a known fixed size, all of its data members must have fixed size. If this type includes, for example, a variable-sized array, then it does not have a known fixed size.

For example, a string object (`[]const u8`, an array of constant `u8`) has a variable size. If we do not know at compile time which string will be stored, then we cannot calculate the size of this string object at compile time. Any type/struct that includes a string without an explicit fixed size therefore doesn’t have a known fixed size at compile time.

In contrast, if the type includes an array with a known fixed size like `[60]u8`, then the type **does** have a known fixed size at compile time. In this case, the compiler does not need to know any object’s exact value at compile time, since it can find the necessary storage size by looking at the type.

Example:

```zig
fn input_length(input: []const u8) usize {
    const n = input.len;
    return n;
}

pub fn main() !void {
    const name = "Pedro";
    const array = [_]u8{1, 2, 3, 4};
    _ = name; _ = array;
}
````

The other side of the spectrum are objects whose values are not known at compile time. Function arguments are a classic example: their value depends on what you pass at the callsite.

In `input_length()`, the `input` argument is `[]const u8`. It’s impossible to know this argument’s value or length at compile time. As a consequence, `input.len` is also only known at runtime.

However, what really matters to the compiler is the **size** of the result type at compile time. Although we don’t know the **value** of `n` at compile time, we do know its **type** is `usize`, which has a known fixed size.

### 3.1.2  Global data register

The global data register is a specific section of the executable responsible for storing any value that is known at compile time.

Every constant object whose value is known at compile time, and every literal (like `"this is a string"`, `10`, or `true`), is stored in the global data register.

You generally don’t need to care about this memory space—it’s managed by the compiler and doesn’t affect your program’s logic.

### 3.1.3  Stack vs Heap

“Stack vs Heap” are two different memory spaces, both available in Zig. They’re complementary, and most Zig programs use both.

* The **stack** is normally used to store values whose length is fixed and known at compile time.
* The **heap** is a dynamic memory space, used to store values whose length might grow during program execution.

Objects whose length may grow at runtime are intrinsically “runtime-known”. These should be stored in the heap, which can grow or shrink to fit your objects.

### 3.1.4  Stack

The stack uses a Last-In, First-Out (LIFO) mechanism. It adds and removes values by following this principle.

Every time you make a function call in Zig, an amount of stack space is reserved for that call. Function arguments and local objects are usually stored in that space.

```zig
fn add(x: u8, y: u8) u8 {
    const result = x + y;
    return result;
}

pub fn main() !void {
    const r = add(5, 27);
    _ = r;
}
```

Local objects declared inside a function scope are stored in that function’s stack space. The same applies to objects declared in `main()`—they go in `main`’s stack frame.

A very important detail: **stack memory frees itself automatically**. When a function returns, its stack space is destroyed, and all objects in that space go away with it.

> **Important:** Local objects stored on the stack are automatically destroyed at the end of the function scope.

This also applies to any scope delimited by `{}` (loops, `if/else`, etc.). A local declared inside a loop exists only within that loop’s scope.

```zig
// This does not compile successfully!
const a = [_]u8{0, 1, 2, 3, 4};
for (0..a.len) |i| {
    const index = i;
    _ = index;
}
// This is out of scope; `index` no longer exists.
std.debug.print("{d}\n", .{index});
```

Once the function returns, you can no longer access any memory addresses from that function’s stack space. Therefore, **you must not return a pointer to a stack-allocated local**.

It may compile, but it’s undefined behavior:

```zig
fn add(x: u8, y: u8) *const u8 {
    const result = x + y;
    return &result;
}

pub fn main() !void {
    // Compiles, but `r` is undefined. Never do this!
    const r = add(5, 27); _ = r;
}
```

> **Important:** Never return a pointer to a local object stored on the stack. After the function returns, that memory no longer exists.

If you need to use an object after the function returns, allocate it on the **heap** and return a pointer to that heap object.

### 3.1.5  Heap

A key limitation of the stack is that only objects with compile-time-known size can be stored in it. The heap is more dynamic and fits objects whose size might grow during execution.

Servers are a classic use case: they don’t know up front how many requests they’ll receive. The heap lets you allocate and manage memory according to demand.

Another key difference: the heap is under **your** control. You decide where/how much to allocate and when to free it. Unlike stack memory, heap memory is explicitly allocated and won’t be deallocated until explicitly freed.

To store an object in the heap, you must ask an **allocator** to allocate space in the heap.

> **Important:** Every heap allocation must be explicitly freed by you.

Most Zig allocators allocate on the heap. Exceptions include `ArenaAllocator()` (works with a child allocator) and `FixedBufferAllocator()` (which can be stack-backed if you give it a stack buffer).

### 3.1.6  Summary

* Literal values (e.g., `"this is string"`, `10`, `true`) → global data section.
* Constant objects (`const`) whose value is known at compile time → global data section.
* Objects (constant or not) whose size is known at compile time → stack (current scope).
* Objects created via an allocator’s `alloc()` or `create()` → live in the memory space used by that allocator (usually the heap; `FixedBufferAllocator()` is an exception).
* The heap can only be accessed through allocators. If you didn’t use `alloc()`/`create()`, it’s almost certainly not on the heap.

## 3.2  Stack overflows

Stack allocation is generally faster than heap allocation, but the stack has restrictions—most notably, its **limited size** (which varies by system). We typically store only temporary and small objects on the stack.

If you allocate more than the stack can hold, a **stack overflow** happens and your program crashes.

Example (allocating a very big array on the stack):

```zig
var very_big_alloc: [1000 * 1000 * 24]u64 = undefined;
@memset(very_big_alloc[0..], 0);

// Segmentation fault (core dumped)
```

This segmentation fault results from a stack overflow. Very big objects should usually be stored on the heap.

## 3.3  Allocators

A key aspect of Zig: there are **no hidden memory allocations**. If a function/operator needs to allocate memory, it must take an **allocator** argument from the user. This makes allocation explicit and visible.

Example using `std.fmt.allocPrint()` (which needs to allocate space for the formatted string):

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const name = "Pedro";
const output = try std.fmt.allocPrint(
    allocator,
    "Hello {s}!!!",
    .{name}
);
try stdout.print("{s}\n", .{output});
try stdout.flush();

// Hello Pedro!!!
```

By supplying the allocator, you control where and how much memory can be allocated.

### 3.3.1  What are allocators?

Allocators in Zig are objects you use to allocate memory for your program (similar to C’s `malloc()`/`calloc()`). They’re usually available from `std.heap`. All allocators implement a common interface providing `alloc()`, `free()`, `create()`, and `destroy()`.

### 3.3.2  Why you need an allocator?

The stack requires fixed-size objects. In practice:

* Objects may need to grow during execution.
* You often can’t know up front how many inputs you’ll receive or how big they’ll be.
* You may want to return a **pointer** to a local object. You can’t do that with stack memory (it goes out of scope), but you can with heap memory you control.

These are common situations where the heap is a better fit. Allocating memory on the heap is **dynamic memory management**—as your objects grow, you allocate more memory via an allocator.

### 3.3.3  The different types of allocators

At the time of writing, Zig offers these allocators in the standard library:

* `GeneralPurposeAllocator()`
* `page_allocator()`
* `FixedBufferAllocator()` and `ThreadSafeFixedBufferAllocator()`
* `ArenaAllocator()`
* `c_allocator()` (requires linking to libc)

All except `FixedBufferAllocator()` and (by itself) `ArenaAllocator()` are heap allocators.

### 3.3.4  General-purpose allocators

`GeneralPurposeAllocator()` is the “go-to” allocator.

```zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const some_number = try allocator.create(u32);
    defer allocator.destroy(some_number);

    some_number.* = @as(u32, 45);
}
```

You can also use `c_allocator()` (an alias to C’s standard `malloc()`). If you use `c_allocator()`, you must link to libc with `-lc` when compiling.

### 3.3.5  Page allocator

`page_allocator()` allocates **full pages** of memory (often 4 KB) for each allocation. It’s fast but can be wasteful if you need only a few bytes.

### 3.3.6  Buffer allocators

`FixedBufferAllocator()` and `ThreadSafeFixedBufferAllocator()` work with a **fixed-size buffer** you provide. They reserve space inside that buffer.

They can allocate from the **stack** or the **heap** depending on where the backing buffer lives.

Stack-backed example:

```zig
var buffer: [10]u8 = undefined;
for (0..buffer.len) |i| {
    buffer[i] = 0; // Initialize to zero
}

var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();
const input = try allocator.alloc(u8, 5);
defer allocator.free(input);
```

Heap-backed example (big buffer):

```zig
const heap = std.heap.page_allocator;
const memory_buffer = try heap.alloc(u8, 100 * 1024 * 1024); // 100 MB
defer heap.free(memory_buffer);

var fba = std.heap.FixedBufferAllocator.init(memory_buffer);
const allocator = fba.allocator();

const input = try allocator.alloc(u8, 1000);
defer allocator.free(input);
```

### 3.3.7  Arena allocator

`ArenaAllocator()` takes a **child allocator** and lets you allocate many times and then free **everything at once** with `deinit()`.

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var aa = std.heap.ArenaAllocator.init(gpa.allocator());
defer aa.deinit();
const allocator = aa.allocator();

const in1 = try allocator.alloc(u8, 5);
const in2 = try allocator.alloc(u8, 10);
const in3 = try allocator.alloc(u8, 15);
_ = in1; _ = in2; _ = in3;
```

Without an arena, you’d need to call `free()` for each allocation.

### 3.3.8  The `alloc()` and `free()` methods

The example below reads from standard input and stores it in heap-allocated memory:

```zig
const std = @import("std");
var stdin_buffer: [1024]u8 = undefined;
var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
const stdin = &stdin_reader.interface;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var input = try allocator.alloc(u8, 50);
    defer allocator.free(input);
    @memset(input[0..], 0);

    // Read user input
    stdin.readSliceAll(input[0..]) catch |err| switch (err) {
        error.EndOfStream => {}, // Reached end of input
        else => return err,
    };
    std.debug.print("{s}\n", .{input});
}
```

`alloc(Type, count)` allocates an array of `count` items of `Type`. You must eventually call `free()` on the **same allocator**. Using `defer` helps ensure you free at the end of scope.

### 3.3.9  The `create()` and `destroy()` methods

Use `create()`/`destroy()` for **single items**. Use `alloc()`/`free()` for **arrays**.

```zig
const std = @import("std");

const User = struct {
    id: usize,
    name: []const u8,

    pub fn init(id: usize, name: []const u8) User {
        return .{ .id = id, .name = name };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const user = try allocator.create(User);
    defer allocator.destroy(user);

    user.* = User.init(0, "Pedro");
}
```

