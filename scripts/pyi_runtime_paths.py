import sys
from pathlib import Path
import os

# Ensure bundled exe can import project packages (src) when frozen.
def _add(path: Path):
    if path and path.exists():
        p = str(path)
        if p not in sys.path:
            sys.path.insert(0, p)

if getattr(sys, "frozen", False):
    base = Path(getattr(sys, "_MEIPASS", Path(sys.executable).parent))
    exe_dir = Path(sys.executable).parent
    for candidate in (base, base / "src", exe_dir, exe_dir / "src"):
        _add(candidate)

    # Ensure Windows can resolve bundled numerical runtime DLLs (MKL/OpenMP).
    if os.name == "nt":
        dll_candidates = [
            base,
            base / "Library" / "bin",
            base / "numpy" / ".libs",
            exe_dir,
        ]
        for dll_dir in dll_candidates:
            if not dll_dir.exists():
                continue
            try:
                os.add_dll_directory(str(dll_dir))
            except (AttributeError, FileNotFoundError, OSError):
                # Keep compatibility with older Python/Windows builds.
                pass

        # Fallback for third-party loaders that still rely on PATH.
        existing_path = os.environ.get("PATH", "")
        prepend = [str(p) for p in dll_candidates if p.exists()]
        if prepend:
            os.environ["PATH"] = os.pathsep.join(prepend + ([existing_path] if existing_path else []))
else:
    here = Path(__file__).resolve().parent
    project_root = here.parent
    for candidate in (project_root, project_root / "src"):
        _add(candidate)
