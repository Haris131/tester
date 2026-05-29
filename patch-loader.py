import sys
import os

filepath = sys.argv[1] if len(sys.argv) > 1 else "edlclient/Library/loader_db.py"

with open(filepath, "r") as f:
    code = f.read()

old = (
    '    def init_loader_db(self):\n'
    '        for (dirpath, dirnames, filenames) in os.walk(os.path.join(parent_dir, "..", "Loaders")):\n'
    '            for filename in filenames:\n'
    '                fn = os.path.join(dirpath, filename)\n'
    '                found = False\n'
    '                for ext in [".bin", ".mbn", ".elf"]:\n'
    '                    if ext in filename[-4:]:\n'
    '                        found = True\n'
    '                        break\n'
    '                if not found:\n'
    '                    continue\n'
    '                try:\n'
    '                    hwid = filename.split("_")[0].lower()\n'
    '                    msmid = hwid[:8]\n'
    '                    try:\n'
    '                        int(msmid, 16)\n'
    '                    except:\n'
    '                        continue\n'
    '                    devid = hwid[8:]\n'
    '                    if devid == \'\':\n'
    '                        continue\n'
    '                    if len(filename.split("_")) < 2:\n'
    '                        continue\n'
    '                    pkhash = filename.split("_")[1].lower()\n'
    '                    for msmid in self.convertmsmid(msmid):\n'
    '                        mhwid = msmid + devid\n'
    '                        mhwid = mhwid.lower()\n'
    '                        if mhwid not in self.loaderdb:\n'
    '                            self.loaderdb[mhwid] = {}\n'
    '                        if pkhash not in self.loaderdb[mhwid]:\n'
    '                            self.loaderdb[mhwid][pkhash] = fn\n'
    '                except Exception as e:  # pylint: disable=broad-except\n'
    '                    self.debug(f"Filename:{filename} => {str(e)}")\n'
    '                    continue\n'
    '        return self.loaderdb'
)

new = (
    '    def init_loader_db(self):\n'
    '        search_paths = []\n'
    '        try:\n'
    '            if getattr(sys, \'frozen\', False) and hasattr(sys, \'_MEIPASS\'):\n'
    '                p = os.path.join(sys._MEIPASS, "Loaders")\n'
    '                if os.path.isdir(p):\n'
    '                    search_paths.append(p)\n'
    '        except:\n'
    '            pass\n'
    '        try:\n'
    '            exe_dir = os.path.dirname(os.path.abspath(sys.executable))\n'
    '            p = os.path.normpath(os.path.join(exe_dir, "..", "share", "termux-edl", "Loaders"))\n'
    '            if os.path.isdir(p):\n'
    '                search_paths.append(p)\n'
    '        except:\n'
    '            pass\n'
    '        p = os.path.join(parent_dir, "..", "Loaders")\n'
    '        if os.path.isdir(p):\n'
    '            search_paths.append(p)\n'
    '        p = os.path.join(os.getcwd(), "Loaders")\n'
    '        if os.path.isdir(p):\n'
    '            search_paths.append(p)\n'
    '        self.loaderdb = {}\n'
    '        for search_path in search_paths:\n'
    '            for (dirpath, dirnames, filenames) in os.walk(search_path):\n'
    '                for filename in filenames:\n'
    '                    fn = os.path.join(dirpath, filename)\n'
    '                    found = False\n'
    '                    for ext in [".bin", ".mbn", ".elf"]:\n'
    '                        if ext in filename[-4:]:\n'
    '                            found = True\n'
    '                            break\n'
    '                    if not found:\n'
    '                        continue\n'
    '                    try:\n'
    '                        hwid = filename.split("_")[0].lower()\n'
    '                        msmid = hwid[:8]\n'
    '                        try:\n'
    '                            int(msmid, 16)\n'
    '                        except:\n'
    '                            continue\n'
    '                        devid = hwid[8:]\n'
    '                        if devid == \'\':\n'
    '                            continue\n'
    '                        if len(filename.split("_")) < 2:\n'
    '                            continue\n'
    '                        pkhash = filename.split("_")[1].lower()\n'
    '                        for msmid in self.convertmsmid(msmid):\n'
    '                            mhwid = msmid + devid\n'
    '                            mhwid = mhwid.lower()\n'
    '                            if mhwid not in self.loaderdb:\n'
    '                                self.loaderdb[mhwid] = {}\n'
    '                            if pkhash not in self.loaderdb[mhwid]:\n'
    '                                self.loaderdb[mhwid][pkhash] = fn\n'
    '                    except Exception as e:\n'
    '                        self.debug(f"Filename:{filename} => {str(e)}")\n'
    '                        continue\n'
    '        return self.loaderdb'
)

if old not in code:
    print("ERROR: Could not find original init_loader_db code")
    sys.exit(1)

code = code.replace(old, new, 1)

with open(filepath, "w") as f:
    f.write(code)

print(f"Patched {filepath} successfully")
