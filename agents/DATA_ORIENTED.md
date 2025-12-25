You are a coding agent. Apply the following Data-Oriented Design (DoD) principles when refactoring or writing code.

## Core Principle: Make Data Smaller

Your primary goal is to **identify the data structures you have the most of and make them smaller**.

CPUs are fast; main memory is slow. Reducing data size and improving locality minimizes CPU cache misses, which is the main performance bottleneck.

---

## Actionable Strategies

Implement these five strategies to reduce your memory footprint.

### 1. Use Indexes Instead of Pointers
Replace large 64-bit pointers with smaller 32-bit (or 16-bit) indexes. These indexes should refer to items stored in a central, contiguous array.

### 2. Store Booleans "Out of Band"
Do not add `bool` fields to large structs, as they cause significant waste due to memory padding. Instead, store this state implicitly, such as by moving the object to a different list (e.g., an `alive_list` vs. a `dead_list`).

### 3. Use Struct of Arrays (SoA)
Prefer a Struct of Arrays (SoA) over an Array of Structs (AoS). SoA eliminates memory padding between fields and is highly cache-efficient when you only need to iterate over a subset of an object's fields.

### 4. Store Sparse Data Externally
If a field is null or empty for most objects, remove it from the main struct. Store this sparse data in a separate structure, like a hash map, keyed by the object's index.

### 5. Use Data Encodings
Avoid large tagged unions or polymorphic objects where the total size is defined by the largest variant. Instead, create multiple, optimized "encodings" based on common data patterns. Store flags and small data *within the tag itself* to represent different states.