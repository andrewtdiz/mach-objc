# Zig MultiArrayList Reference

`std.MultiArrayList(T)` stores each field of `T` in its own contiguous array. This keeps data oriented while exposing helpers to rebuild full `T` values when needed.

- **Create a list**
  ```zig
  const List = std.MultiArrayList(ObjectData);
  var list = List.empty;
  defer list.deinit(allocator);
  ```

- **Append data**
  ```zig
  try list.append(allocator, ObjectData{
      .guid = guid,
      .transform = transform,
  });
  ```

- **Access a single field column**
  ```zig
  const transforms = list.items(.transform); // []Transform
  transforms[index] = updated_transform;
  ```

- **Reconstruct a struct value**
  ```zig
  const object_data = list.get(index); // ObjectData copy
  ```

- **Precompute field pointers when reading many columns**
  ```zig
  const slice = list.slice();           // MultiArrayList(ObjectData).Slice
  const guids = slice.items(.guid);     // []Guid
  const transforms = slice.items(.transform);
  ```

- **Capacity management**
  ```zig
  try list.ensureUnusedCapacity(allocator, count);
  _ = list.pop(); // remove last element if present
  ```

- **Cleanup**
  ```zig
  list.deinit(allocator);
  ```

Always convert logical identifiers to `usize` indices before indexing: `const idx: usize = @intCast(object_id);`. Use `list.items(field)` for in-place updates and `list.get(index)` when a temporary `T` value is required.
