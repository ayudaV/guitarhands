# Introduction

EN:
This project was developed by Gamux in partnership with Iris Data Science.
The game is a non-profit experimental project focused on learning Motion Capture
using opencv-python and mediapipe, and on exploring a Godot build integrated with
Python libraries via the py4godot addon by niklas2902:
https://github.com/niklas2902/py4godot.

PT-BR:
Este projeto foi desenvolvido pela Gamux em parceria com a Iris Data Science.
O jogo e um projeto experimental sem fins lucrativos com o objetivo de aprofundar
os aprendizados em Motion Capture atraves das ferramentas opencv-python e mediapipe,
além do aprendizado de Godot que foi modificado para se integrar com as libs
python atraves do addon py4godot desenvolvido por niklas2902:
https://github.com/niklas2902/py4godot.

## Prerequisites

- Python (Recommended version: 3.12.4)
- Godot (Version: 4.6, based on plugin compatibility)
- `py4godot` plugin

# Installation

## Windows

1. Download the plugin ZIP:
	- https://github.com/niklas2902/py4godot/releases/download/4.6-alpha15/py4godot.zip
2. Unzip it and copy the inner `py4godot` folder to your install directory:
	- `\install_dir\py4godot`
	- Note: the ZIP contains a top-level folder; use the inner `py4godot`.
3. Copy the dependency list:
	- Copy `requirements.txt` from the project root to `addons/py4godot/dependencies.txt`
4. Install dependencies for the bundled runtime:

```bash
addons/py4godot/cpython-3.12.4-windows64/python/python.exe addons/py4godot/install_dependencies.py
```

## Linux

1. Download the plugin ZIP:
	- https://github.com/niklas2902/py4godot/releases/download/4.6-alpha15/py4godot.zip
2. Unzip it and copy the inner `py4godot` folder to your install directory:
	- `/install_dir/py4godot`
	- Note: the ZIP contains a top-level folder; use the inner `py4godot`.
3. Copy the dependency list:
	- Copy `requirements.txt` from the project root to `addons/py4godot/dependencies.txt`
4. Install dependencies for the bundled runtime:

```bash
addons/py4godot/cpython-3.12.4-linux64/python/python.exe addons/py4godot/install_dependencies.py
```

These steps configure the py4godot runtime used by Godot when running the project.

## Documentation

- [Load and Save System](docs/load_save_system.md)
- [Track Builder](docs/track_builder.md)

## VS Code Setup (py4godot Imports)

The py4godot addon bundles its own Python runtime inside the project. Godot runs
that bundled interpreter, not your system Python. To make VS Code recognize
`py4godot.classes.*` and other bundled modules, add the bundled paths to
Pylance/Pyright.

Example `.vscode/settings.json`:

```json
{
	"python.analysis.extraPaths": [
		"${workspaceFolder}/addons/py4godot",
		"${workspaceFolder}/addons/py4godot/cpython-3.12.4-windows64/python/Lib/site-packages"
	]
}
```

On Linux, use:

```
${workspaceFolder}/addons/py4godot/cpython-3.12.4-linux64/python/lib/python3.12/site-packages
```