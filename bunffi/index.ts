import { dlopen, FFIType, suffix, ptr } from "bun:ffi";

// Path to the compiled dynamic library
const libPath = process.env.MACH_LIB_PATH ?? `../zig-out/lib/libmach-ffi.${suffix}`;

// FFI type shortcuts
const { i32, u32, void: ffi_void, cstring, ptr: ffi_ptr } = FFIType;

// Load the native library
const lib = dlopen(libPath, {
  // Lifecycle
  mach_init: { args: [u32, u32], returns: i32 },
  mach_destroy: { args: [], returns: ffi_void },

  // Event loop
  mach_poll_events: { args: [], returns: i32 },
  mach_render: { args: [], returns: i32 },
  mach_tick: { args: [], returns: i32 },

  // Window control
  mach_focus_window: { args: [], returns: ffi_void },
  mach_minimize: { args: [], returns: ffi_void },
  mach_maximize: { args: [], returns: ffi_void },
  mach_restore: { args: [], returns: ffi_void },
  mach_close: { args: [], returns: ffi_void },
  mach_is_window_active: { args: [], returns: i32 },
  mach_is_minimized: { args: [], returns: i32 },

  // Window size
  mach_get_width: { args: [], returns: u32 },
  mach_get_height: { args: [], returns: u32 },
  mach_set_size: { args: [u32, u32], returns: ffi_void },

  // Mouse state
  mach_get_mouse_x: { args: [], returns: i32 },
  mach_get_mouse_y: { args: [], returns: i32 },
  mach_is_left_button_down: { args: [], returns: i32 },
  mach_is_right_button_down: { args: [], returns: i32 },
  mach_get_mouse_delta_x: { args: [], returns: i32 },
  mach_get_mouse_delta_y: { args: [], returns: i32 },

  // Cursor
  mach_set_cursor: { args: [u32], returns: ffi_void },

  // Clipboard
  mach_set_clipboard: { args: [cstring], returns: i32 },
  mach_get_clipboard: { args: [ffi_ptr, u32], returns: i32 },

  // Keyboard
  mach_get_modifiers: { args: [], returns: u32 },
  mach_key_event_count: { args: [], returns: u32 },
  mach_get_key_event: { args: [u32, ffi_ptr, ffi_ptr], returns: i32 },
  mach_clear_key_events: { args: [], returns: ffi_void },
  mach_text_event_count: { args: [], returns: u32 },
  mach_get_text_event: { args: [u32, ffi_ptr, u32], returns: i32 },
  mach_clear_text_events: { args: [], returns: ffi_void },

  // App icon
  mach_set_app_icon: { args: [cstring], returns: ffi_void },

  // Text input
  mach_enable_text_input: { args: [], returns: ffi_void },
  mach_disable_text_input: { args: [], returns: ffi_void },
  mach_is_text_input_active: { args: [], returns: i32 },
});

const { symbols } = lib;

// Cursor types matching input.zig CursorType enum
export enum CursorType {
  Default = 0,
  None = 1,
  ContextMenu = 2,
  Help = 3,
  Pointer = 4,
  Progress = 5,
  Wait = 6,
  Cell = 7,
  Crosshair = 8,
  Text = 9,
  VerticalText = 10,
  Alias = 11,
  Copy = 12,
  Move = 13,
  NoDrop = 14,
  NotAllowed = 15,
  Grab = 16,
  Grabbing = 17,
  ResizeE = 18,
  ResizeN = 19,
  ResizeNE = 20,
  ResizeNW = 21,
  ResizeS = 22,
  ResizeSE = 23,
  ResizeSW = 24,
  ResizeW = 25,
  ResizeEW = 26,
  ResizeNS = 27,
  ResizeNESW = 28,
  ResizeNWSE = 29,
  ResizeCol = 30,
  ResizeRow = 31,
  ResizeAll = 32,
  ZoomIn = 33,
  ZoomOut = 34,
}

// Key action types
export enum KeyAction {
  Down = 0,
  Repeat = 1,
  Up = 2,
}

// Modifier flags
export enum Modifier {
  None = 0,
  Shift = 1,
  Control = 2,
  Alt = 4,
  Command = 8,
}

// Key event interface
export interface KeyEvent {
  keyCode: number;
  action: KeyAction;
  modifiers: number;
}

// Mouse state interface
export interface MouseState {
  x: number;
  y: number;
  leftButtonDown: boolean;
  rightButtonDown: boolean;
  deltaX: number;
  deltaY: number;
}

// Window size interface
export interface Size {
  width: number;
  height: number;
}

/**
 * MachWindow - A class wrapping the native mach-objc window
 */
export class MachWindow {
  private initialized = false;

  /**
   * Initialize the window with the specified dimensions
   */
  init(width = 800, height = 600): boolean {
    const result = symbols.mach_init(width, height);
    this.initialized = result === 0;
    return this.initialized;
  }

  /**
   * Destroy the window and clean up resources
   */
  destroy(): void {
    if (this.initialized) {
      symbols.mach_destroy();
      this.initialized = false;
    }
  }

  /**
   * Poll for system events
   * Returns true if the window should continue running
   */
  pollEvents(): boolean {
    return symbols.mach_poll_events() === 1;
  }

  /**
   * Render a frame
   * Returns true if rendering was successful
   */
  render(): boolean {
    return symbols.mach_render() === 1;
  }

  /**
   * Combined poll and render (convenience method)
   * Returns true if window should continue running
   */
  tick(): boolean {
    return symbols.mach_tick() === 1;
  }

  /**
   * Run the main loop with a callback
   * The callback is called once per frame
   */
  run(onFrame?: () => void): void {
    while (this.tick()) {
      onFrame?.();
    }
    this.destroy();
  }

  // Window control methods
  focus(): void {
    symbols.mach_focus_window();
  }

  minimize(): void {
    symbols.mach_minimize();
  }

  maximize(): void {
    symbols.mach_maximize();
  }

  restore(): void {
    symbols.mach_restore();
  }

  close(): void {
    symbols.mach_close();
  }

  get isActive(): boolean {
    return symbols.mach_is_window_active() === 1;
  }

  get isMinimized(): boolean {
    return symbols.mach_is_minimized() === 1;
  }

  // Window size
  get width(): number {
    return symbols.mach_get_width();
  }

  get height(): number {
    return symbols.mach_get_height();
  }

  get size(): Size {
    return { width: this.width, height: this.height };
  }

  setSize(width: number, height: number): void {
    symbols.mach_set_size(width, height);
  }

  // Mouse state
  get mouseX(): number {
    return symbols.mach_get_mouse_x();
  }

  get mouseY(): number {
    return symbols.mach_get_mouse_y();
  }

  get mouseState(): MouseState {
    return {
      x: symbols.mach_get_mouse_x(),
      y: symbols.mach_get_mouse_y(),
      leftButtonDown: symbols.mach_is_left_button_down() === 1,
      rightButtonDown: symbols.mach_is_right_button_down() === 1,
      deltaX: symbols.mach_get_mouse_delta_x(),
      deltaY: symbols.mach_get_mouse_delta_y(),
    };
  }

  get isLeftButtonDown(): boolean {
    return symbols.mach_is_left_button_down() === 1;
  }

  get isRightButtonDown(): boolean {
    return symbols.mach_is_right_button_down() === 1;
  }

  // Cursor
  setCursor(cursor: CursorType): void {
    symbols.mach_set_cursor(cursor);
  }

  // Clipboard
  setClipboard(text: string): boolean {
    const buffer = Buffer.from(text + "\0", "utf8");
    return symbols.mach_set_clipboard(ptr(buffer)) === 0;
  }

  getClipboard(): string | null {
    const buffer = new Uint8Array(4096);
    const len = symbols.mach_get_clipboard(ptr(buffer), buffer.length);
    if (len < 0) return null;
    return new TextDecoder().decode(buffer.subarray(0, len));
  }

  // Keyboard
  get modifiers(): number {
    return symbols.mach_get_modifiers();
  }

  get isShiftDown(): boolean {
    return (this.modifiers & Modifier.Shift) !== 0;
  }

  get isControlDown(): boolean {
    return (this.modifiers & Modifier.Control) !== 0;
  }

  get isAltDown(): boolean {
    return (this.modifiers & Modifier.Alt) !== 0;
  }

  get isCommandDown(): boolean {
    return (this.modifiers & Modifier.Command) !== 0;
  }

  /**
   * Get all pending key events
   */
  getKeyEvents(): KeyEvent[] {
    const count = symbols.mach_key_event_count();
    const events: KeyEvent[] = [];
    const actionBuffer = new Uint32Array(1);
    const modsBuffer = new Uint32Array(1);

    for (let i = 0; i < count; i++) {
      const keyCode = symbols.mach_get_key_event(i, ptr(actionBuffer), ptr(modsBuffer));
      if (keyCode >= 0) {
        events.push({
          keyCode,
          action: actionBuffer[0]! as KeyAction,
          modifiers: modsBuffer[0]!,
        });
      }
    }
    return events;
  }

  /**
   * Clear pending key events
   */
  clearKeyEvents(): void {
    symbols.mach_clear_key_events();
  }

  /**
   * Get all pending text input events
   */
  getTextEvents(): string[] {
    const count = symbols.mach_text_event_count();
    const events: string[] = [];
    const buffer = new Uint8Array(16);

    for (let i = 0; i < count; i++) {
      const len = symbols.mach_get_text_event(i, ptr(buffer), buffer.length);
      if (len > 0) {
        events.push(new TextDecoder().decode(buffer.subarray(0, len)));
      }
    }
    return events;
  }

  /**
   * Clear pending text events
   */
  clearTextEvents(): void {
    symbols.mach_clear_text_events();
  }

  // App icon
  setAppIcon(path: string): void {
    const buffer = Buffer.from(path + "\0", "utf8");
    symbols.mach_set_app_icon(ptr(buffer));
  }

  // Text input mode
  enableTextInput(): void {
    symbols.mach_enable_text_input();
  }

  disableTextInput(): void {
    symbols.mach_disable_text_input();
  }

  get isTextInputActive(): boolean {
    return symbols.mach_is_text_input_active() === 1;
  }
}

// Export a singleton for convenience
export const window = new MachWindow();

// Export the library for direct access if needed
export { lib, symbols };
