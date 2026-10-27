"""Build a reproducible, source-complete SL test archive (no credentials)."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile
from build import ROOT, build

def package(output=None):
    build(check=True)
    output=Path(output or ROOT/'dist/Dream-Farming-SL-Test-Candidate.zip')
    output.parent.mkdir(parents=True,exist_ok=True)
    files={}
    for folder in ['lsl','src','docs','cloudflare','tests','tools']:
        for path in sorted((ROOT/folder).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts and path.suffix!='.pyc':
                files[path.relative_to(ROOT).as_posix()]=path.read_bytes()
    for name in ['README.md','CHANGELOG.md','requirements-dev.txt']:
        files[name]=(ROOT/name).read_bytes()
    files['START_HERE.md']=(ROOT/'docs/SL_TEST_CANDIDATE.md').read_bytes()
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=bool(subprocess.check_output(['git','status','--porcelain','--untracked-files=normal'],cwd=ROOT,text=True).strip())
    manifest={'label':'Dream Farming SL Test Candidate','source_commit':commit,'working_tree_modified':dirty,
              'simulator_validation':'NOT RUN: Second Life Mono, memory, physics and live integration require owner testing',
              'files':{name:hashlib.sha256(data).hexdigest() for name,data in sorted(files.items())}}
    files['MANIFEST.json']=(json.dumps(manifest,indent=2,sort_keys=True)+'\n').encode()
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED) as archive:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,10,26,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(info,data)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        for name,checksum in manifest['files'].items():
            assert hashlib.sha256(archive.read(name)).hexdigest()==checksum
    print(f'{output}: {len(files)} files; {len(list((ROOT/"lsl").glob("*.lsl")))} standalone LSL scripts; commit {commit}; modified={dirty}')
    return output

if __name__=='__main__':
    package()
