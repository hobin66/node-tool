import os
import shutil
import subprocess
import sys
import platform
import zipfile

# ---------------------------------------------------------
# Configuration Area
# ---------------------------------------------------------
PROJECT_NAME = "NodeTool"  # Generated exe/binary name
SPEC_FILE = "node_tool.spec"  # PyInstaller spec file
DIST_DIR = "dist"
BUILD_DIR = "build"
RELEASE_DIR = "release"  # Final release directory

# External assets to copy to the release directory
# Format: (Source Path, Destination Folder Name)
EXTERNAL_ASSETS = [
    # (Source, Destination: empty string means root)
    ("app/subscription/nodes", "nodes"),  # Copy nodes folder
    ("db_config.json", ""),      # Copy db config if exists
    ("app.db", ""),              # Copy database if exists (optional)
]

def clean_dirs():
    """Clean up temporary build directories"""
    print(f"[Clean] Cleaning up old build files...")
    for d in [DIST_DIR, BUILD_DIR, RELEASE_DIR]:
        if os.path.exists(d):
            shutil.rmtree(d, ignore_errors=True)

def run_pyinstaller():
    """Run PyInstaller"""
    print(f"[Build] Starting PyInstaller build ({platform.system()})...")
    
    # Check if spec file exists
    if not os.path.exists(SPEC_FILE):
        print(f"[Error] Error: {SPEC_FILE} not found. Please generate the spec file first.")
        sys.exit(1)

    # Run PyInstaller command
    try:
        subprocess.check_call([sys.executable, "-m", "PyInstaller", SPEC_FILE, "--clean", "-y"])
        print("[Success] PyInstaller build completed")
    except subprocess.CalledProcessError:
        print("[Error] PyInstaller build failed")
        sys.exit(1)

def organize_release():
    """Organize release folder: copy exe and external assets"""
    print(f"[Organize] Organizing release files to '{RELEASE_DIR}'...")
    
    if not os.path.exists(RELEASE_DIR):
        os.makedirs(RELEASE_DIR)

    # 1. Determine the executable name
    system_name = platform.system()
    exe_name = f"{PROJECT_NAME}.exe" if system_name == "Windows" else PROJECT_NAME
    
    src_exe = os.path.join(DIST_DIR, exe_name)
    dst_exe = os.path.join(RELEASE_DIR, exe_name)

    if not os.path.exists(src_exe):
        print(f"[Error] Error: Generated file not found in dist: {src_exe}")
        sys.exit(1)

    # 2. Move executable
    shutil.copy2(src_exe, dst_exe)
    print(f"   -> Copied executable: {exe_name}")

    # 3. Copy external assets (nodes folder, etc.)
    for src, dst_folder in EXTERNAL_ASSETS:
        # Check if source exists
        if not os.path.exists(src):
            print(f"   [Warning] Warning: Asset not found, skipping: {src}")
            continue

        final_dst = os.path.join(RELEASE_DIR, dst_folder)
        
        if os.path.isdir(src):
            # If it's a directory
            if os.path.exists(final_dst):
                shutil.rmtree(final_dst)
            shutil.copytree(src, final_dst)
            print(f"   -> Copied folder: {src} -> {dst_folder}/")
        else:
            # If it's a file
            shutil.copy2(src, final_dst)
            print(f"   -> Copied file: {src}")

    # 4. Set execution permissions for Linux
    if system_name != "Windows":
        os.chmod(dst_exe, 0o755)

def make_archive():
    """Create archive for release"""
    print("[Compress] Creating archive...")
    
    # Architecture name (e.g., amd64, arm64, win32)
    arch = platform.machine().lower()
    os_name = platform.system().lower()
    zip_name = f"{PROJECT_NAME}_{os_name}_{arch}.zip"
    
    # Change directory to make the archive path clean
    shutil.make_archive(os.path.join(".", zip_name.replace('.zip', '')), 'zip', RELEASE_DIR)
    
    print(f"[Done] Build successful! File located at: {os.path.abspath(zip_name)}")

if __name__ == "__main__":
    clean_dirs()
    run_pyinstaller()
    organize_release()
    make_archive()
