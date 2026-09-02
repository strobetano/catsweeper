"""Decode an APK's binary AndroidManifest and report every <provider> authority.

Usage: python tmp/check_apk.py <path-to-apk>
Exits non-zero if two providers share the same authority (the bug that made
Godot's non-gradle Android export produce uninstallable APKs).
"""
import struct
import sys
import zipfile

data = zipfile.ZipFile(sys.argv[1]).read('AndroidManifest.xml')


def u16(o):
    return struct.unpack_from('<H', data, o)[0]


def u32(o):
    return struct.unpack_from('<I', data, o)[0]


off = 8
strings = []
chunks = []
while off < len(data):
    ctype, hsize, csize = u16(off), u16(off + 2), u32(off + 4)
    if csize == 0:
        break
    chunks.append((ctype, off, hsize))
    if ctype == 0x0001:
        count, flags, sstart = u32(off + 8), u32(off + 16), u32(off + 20)
        utf8 = bool(flags & (1 << 8))
        for i in range(count):
            p = off + sstart + u32(off + hsize + 4 * i)
            if utf8:
                p += 2 if data[p] & 0x80 else 1
                n = data[p]
                if n & 0x80:
                    n, p = ((n & 0x7F) << 8) | data[p + 1], p + 2
                else:
                    p += 1
                strings.append(data[p:p + n].decode('utf-8', 'replace'))
            else:
                n = u16(p)
                if n & 0x8000:
                    n, p = ((n & 0x7FFF) << 16) | u16(p + 2), p + 4
                else:
                    p += 2
                strings.append(data[p:p + n * 2].decode('utf-16-le', 'replace'))
    off += csize


def name(i):
    return strings[i] if 0 <= i < len(strings) else '#%d' % i


def element(off, hsize):
    """Return (tag, {attr: value}) for a start-element chunk."""
    p = off + hsize
    attrs = {}
    astart, asize, acount = u16(p + 8), u16(p + 10), u16(p + 12)
    for i in range(acount):
        a = p + astart + i * asize
        raw = u32(a + 16)
        attrs[name(u32(a + 4))] = name(raw) if data[a + 15] == 0x03 else raw
    return name(u32(p + 4)), attrs


providers = []
for ctype, off, hsize in chunks:
    if ctype != 0x0102:
        continue
    tag, attrs = element(off, hsize)
    if tag == 'provider':
        providers.append(attrs)
    elif tag in ('manifest', 'uses-sdk', 'application'):
        print('%-14s %s' % (tag, ' '.join('%s=%s' % kv for kv in attrs.items())))
print()

seen = {}
clash = False
for a in providers:
    auth = a.get('authorities', '?')
    print('%-45s %s' % (a.get('name', '?'), auth))
    if auth in seen:
        clash = True
    seen[auth] = a.get('name')

print('\nDUPLICATE AUTHORITY' if clash else '\nOK: all provider authorities unique')
sys.exit(1 if clash else 0)
