# MacVimSwitch

> Core input source switching logic based on [macism](https://github.com/laishulu/macism)

[中文说明](README.md) | **English** | [日本語](README_JA.md) | [한국어](README_KO.md)

MacVimSwitch is a macOS menu bar utility designed for Vim users and anyone who frequently switches between Chinese/English input methods.

## Features

- **One-key Switch**: Press ESC (or Ctrl+[) to automatically switch to the selected English input method (only in configured apps)
- **Shift Switch**: Press Shift to quickly toggle between Chinese and English input methods
- **Free Choice**: Select your preferred English and Chinese input methods from the menu bar
- **App Configuration**: Configure which apps ESC switching applies to
- **Launch at Login**: Support for automatic startup

## Supported Applications

Terminal, VSCode, MacVim, Windsurf, Obsidian, Warp, Cursor, and any application with Vim mode.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `ESC` | Switch to English input method |
| `Ctrl + [` | Same as ESC (Vim-compatible) |
| `Shift` | Toggle between Chinese/English |

## Installation

### Homebrew

```bash
brew tap Jackiexiao/tap
brew install --cask macvimswitch
```

### Manual Installation

Download `MacVimSwitch.dmg` from [GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases).

## Usage

1. **First Launch**:
   - Open MacVimSwitch
   - Grant Accessibility permissions when prompted
   - Go to System Settings → Privacy & Security → Accessibility
   - Add and enable MacVimSwitch

2. **Initial Configuration**:
   - Disable "Use Shift to switch between input modes" in your input method preferences
   - Select your preferred Chinese and English input methods from the menu bar icon

3. **Menu Bar Options**:
   - Usage Instructions - View help dialog
   - Select Chinese Input Method
   - Select English Input Method
   - ESC-enabled Applications (multi-select)
   - Enable Shift Key Switching (toggle)
   - Launch at Login (toggle)
   - Quit

## FAQ

### Re-authorization Required After Update

Since the app uses self-signed certificates, each build has a different signature identifier, and macOS recognizes it as a new application.

**Solution**:
1. Open System Settings → Privacy & Security → Accessibility
2. Remove the old MacVimSwitch entry
3. Add the new MacVimSwitch
4. Ensure the toggle is enabled

## Technical Architecture

```
MacVimSwitch/
├── main.swift              # Application entry point
├── AppDelegate.swift       # Application lifecycle management
├── StatusBarManager.swift  # Menu bar UI management
├── inputsource.swift       # Input source switching core logic
│   ├── InputSource         # Input source wrapper
│   ├── InputSourceManager  # Input source management
│   └── KeyboardManager     # Keyboard event monitoring
├── InputMethodManager.swift # Input method discovery and classification
├── UserPreferences.swift   # User preferences
└── LaunchManager.swift     # Login item management
```

### Core Technologies

- **Carbon TIS API**: Input source retrieval and switching
- **CGEvent API**: Global keyboard event monitoring
- **Accessibility**: Keyboard event capture
- **Direct Swift Compilation**: No external dependencies, universal binary

### System Requirements

- macOS 11.0+
- Apple Silicon or Intel Mac

## Development

### Local Build

```bash
./build.sh                    # Build app
./build.sh --create-dmg       # Build and create DMG
```

### Testing

```bash
pkill -f MacVimSwitch
./dist/MacVimSwitch.app/Contents/MacOS/MacVimSwitch
```

### Permission Reset (for testing)

```bash
tccutil reset All com.jackiexiao.macvimswitch
```

## Acknowledgments

- [macism](https://github.com/laishulu/macism) - Input source switching implementation

## License

MIT License
