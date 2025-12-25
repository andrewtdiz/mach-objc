import { MachWindow, CursorType, KeyAction } from "./index";

const win = new MachWindow();

if (!win.init(800, 600)) {
  console.error("Failed to initialize window");
  process.exit(1);
}

console.log("Window initialized:", win.size);

win.setAppIcon("src/assets/appicon.png");

let frameCount = 0;
while (win.tick()) {
  frameCount++;

  if (frameCount % 60 === 0) {
    const mouse = win.mouseState;
    console.log(`Frame ${frameCount} | Mouse: (${mouse.x}, ${mouse.y}) | Size: ${win.width}x${win.height}`);
  }

  const keyEvents = win.getKeyEvents();
  for (const event of keyEvents) {
    if (event.action === KeyAction.Down) {
      console.log(`Key down: ${event.keyCode}, mods: ${event.modifiers}`);

      if (event.keyCode === 256) {
        win.close();
      }
    }
  }
  win.clearKeyEvents();

  const textEvents = win.getTextEvents();
  for (const text of textEvents) {
    console.log(`Text input: "${text}"`);
  }
  win.clearTextEvents();

  if (win.isLeftButtonDown) {
    win.setCursor(CursorType.Pointer);
  } else {
    win.setCursor(CursorType.Default);
  }
}

console.log("Window closed after", frameCount, "frames");
