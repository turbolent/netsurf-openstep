#!/usr/bin/env python3
"""Package an audited OPENSTEP app and its matching source inputs locally."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import struct
import tarfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def add_bytes(archive, name, data, executable=False):
    member = tarfile.TarInfo(name)
    member.size = len(data)
    member.mode = 0o755 if executable else 0o644
    archive.addfile(member, io.BytesIO(data))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True,
                        help='Native tar.gz containing NetSurf.app')
    parser.add_argument('--packages', type=Path, required=True)
    parser.add_argument('--dependency-record', type=Path, required=True,
                        help='SHA256 record of dependency build inputs')
    parser.add_argument('--validation', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--name', default='NetSurf-3.12-dev-openstep-i386-20261002')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    args.output.mkdir(parents=True, exist_ok=True)
    record = json.loads(args.dependency_record.read_text())
    inputs = {}
    for name, expected in record.items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('Unsafe dependency path: ' + name)
        data = (args.packages / path).read_bytes()
        if digest(data) != expected:
            data = data.replace(b'\r\n', b'\n')
        if digest(data) != expected:
            raise ValueError('Dependency input changed: ' + name)
        inputs[name] = data

    names = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
        cwd=root).decode().split('\0')
    source = {}
    for name in sorted(set(names) - {''}):
        path = root / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b'\0' not in data:
            data = data.replace(b'\r\n', b'\n')
        source[name] = data
    manifest = {
        'release': args.name,
        'base_commit': subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip(),
        'source_sha256': {n: digest(d) for n, d in source.items()},
        'dependency_input_sha256': record,
        'dependency_versions': {
            n.split('/')[0]: d.decode().strip()
            for n, d in inputs.items() if n.endswith('/version')},
        'native_app_archive_sha256': digest(args.app.read_bytes()),
        'validation': args.validation.read_text(),
    }
    manifest_data = (json.dumps(manifest, indent=2) + '\n').encode()
    common = {
        'BUILDING.txt': source['frontends/openstep/RELEASE-BUILDING.txt'],
        'README.txt': source['frontends/openstep/RELEASE-README.txt'],
        'VALIDATION.txt': args.validation.read_bytes(),
        'SOURCE-MANIFEST.json': manifest_data,
    }
    source_path = args.output / (args.name + '-source.tar.gz')
    # OPENSTEP's old GNU tar understands GNU long names, not POSIX pax headers.
    with tarfile.open(source_path, 'w:gz', format=tarfile.GNU_FORMAT) as out:
        prefix = args.name + '-source/'
        for name, data in source.items():
            add_bytes(out, prefix + 'netsurf/' + name, data,
                      Path(name).suffix in ('.sh', '.pl', '.py'))
        for name, data in inputs.items():
            add_bytes(out, prefix + 'openstep-pkg/' + name, data,
                      Path(name).name in ('pkg', 'build', 'test', 'post-install'))
        for name, data in common.items():
            add_bytes(out, prefix + name, data)

    binary_path = args.output / (args.name + '.tar.gz')
    with tarfile.open(args.app, 'r:gz') as native:
        members = native.getmembers()
        app_names = {m.name.rstrip('/') for m in members}
        required = {'NetSurf.app/NetSurf', 'NetSurf.app/ca-bundle',
                    'NetSurf.app/Resources/Licenses/NetSurf-COPYING',
                    'NetSurf.app/Resources/Licenses/THIRD_PARTY_NOTICES',
                    'NetSurf.app/Resources/Licenses/libiconv/COPYING.LIB'}
        if not required <= app_names:
            raise ValueError('Missing bundle files: ' + str(required - app_names))
        if sum(n.endswith('.ttf') for n in app_names) != 12:
            raise ValueError('Expected 12 bundled font faces')
        executable = native.extractfile('NetSurf.app/NetSurf').read()
        magic, cpu, subtype, filetype, count, _, flags = struct.unpack_from(
            '<7I', executable)
        if (magic, cpu, filetype) != (0xfeedface, 7, 2) or not flags & 1:
            raise ValueError('Expected an i386 executable with no undefined symbols')
        dependencies = []
        offset = 28
        for _ in range(count):
            command, size = struct.unpack_from('<2I', executable, offset)
            if size < 8 or offset + size > len(executable):
                raise ValueError('Invalid Mach-O load command')
            if command == 12:
                name_offset = struct.unpack_from('<I', executable, offset + 8)[0]
                dependencies.append(executable[offset + name_offset:offset + size]
                                    .split(b'\0')[0].decode())
            offset += size
        expected = {
            '/NextLibrary/Frameworks/Foundation.framework/Versions/B/Foundation',
            '/NextLibrary/Frameworks/AppKit.framework/Versions/B/AppKit',
            '/NextLibrary/Frameworks/System.framework/Versions/A/System'}
        if set(dependencies) != expected:
            raise ValueError('Unexpected runtime libraries: ' + str(dependencies))
        with tarfile.open(binary_path, 'w:gz', format=tarfile.USTAR_FORMAT) as out:
            for member in members:
                if (not member.name.startswith('NetSurf.app/') and
                        member.name.rstrip('/') != 'NetSurf.app'):
                    raise ValueError('Unexpected archive member: ' + member.name)
                if '..' in Path(member.name).parts or member.issym() or member.islnk():
                    raise ValueError('Unexpected link/path in app archive')
                out.addfile(member, native.extractfile(member) if member.isfile() else None)
            for name, data in common.items():
                add_bytes(out, name, data)
    for name, data in common.items():
        (args.output / name).write_bytes(data)
    checksums = ''.join(digest(p.read_bytes()) + '  ' + p.name + '\n'
                        for p in (binary_path, source_path))
    (args.output / 'SHA256SUMS').write_text(checksums, encoding='ascii')
    print(checksums, end='')


if __name__ == '__main__':
    main()
