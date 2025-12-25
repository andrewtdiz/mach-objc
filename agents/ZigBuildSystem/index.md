# Zig Build System

## Table of Contents

- [Getting Started](GettingStarted.md)
  -Simple Executable
  -Installing Build Artifacts
  -Adding a Convenience Step for Running the Application
- [The Basics](Basics.md)
  - User-Provided Options
  - Standard Configuration Options
  - Options for Conditional Compilation
  - Static Library
  - Dynamic Library
  - Testing
  - Linking to System Libraries
- [Generating Files](GeneratingFiles.md)
  -Running System Tools
  -Running the Project's Tools
  -Producing Assets for `@embedFile`
  -Generating Zig Source Code
  -Dealing With One or More Generated Files
  -Mutating Source Files in Place
- [Handy Examples](HandyExamples.md)
  -Build for multiple targets to make a release

## When to bust out the Zig Build System?

The fundamental commands `zig build-exe`, `zig build-lib`, `zig build-obj`, and
`zig test` are often sufficient. However, sometimes a project needs another
layer of abstraction to manage the complexity of building from source.

For example, perhaps one of these situations applies:

- The command line becomes too long and unwieldy, and you want some place to
  write it down.
- You want to build many things, or the build process contains many steps.
- You want to take advantage of concurrency and caching to reduce build time.
- You want to expose configuration options for the project.
- The build process is different depending on the target system and other options.
- You have dependencies on other projects.
- You want to avoid an unnecessary dependency on cmake, make, shell, msvc,
  python, etc., making the project accessible to more contributors.
- You want to provide a package to be consumed by third parties.
- You want to provide a standardized way for tools such as IDEs to semantically understand
  how to build the project.

If any of these apply, the project will benefit from using the Zig Build System.