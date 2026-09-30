import hashlib
import gzip
import json
import struct
import sys
from pathlib import Path


def align(value: int, block: int) -> int:
    return (value + block - 1) // block * block


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def split_components(data: bytes) -> tuple[dict[str, int], dict[str, bytes]]:
    kernel_size, ramdisk_size, second_size = struct.unpack_from("<I4xI4xI", data, 8)
    page_size, header_version, os_version = struct.unpack_from("<III", data, 36)
    recovery_dtbo_size = struct.unpack_from("<I", data, 1632)[0] if header_version >= 1 else 0
    header_size = struct.unpack_from("<I", data, 1644)[0] if header_version >= 1 else page_size
    dtb_size = struct.unpack_from("<I", data, 1648)[0] if header_version >= 2 else 0
    kernel_offset = page_size
    ramdisk_offset = kernel_offset + align(kernel_size, page_size)
    second_offset = ramdisk_offset + align(ramdisk_size, page_size)
    recovery_offset = second_offset + align(second_size, page_size)
    dtb_offset = recovery_offset + align(recovery_dtbo_size, page_size)
    metadata = {
        "page_size": page_size,
        "header_version": header_version,
        "header_size": header_size,
        "os_version_raw": os_version,
    }
    blobs = {
        "kernel": data[kernel_offset : kernel_offset + kernel_size],
        "ramdisk": data[ramdisk_offset : ramdisk_offset + ramdisk_size],
        "second": data[second_offset : second_offset + second_size],
        "recovery_dtbo": data[recovery_offset : recovery_offset + recovery_dtbo_size],
        "dtb": data[dtb_offset : dtb_offset + dtb_size],
    }
    return metadata, blobs


def parse_cpio(data: bytes) -> dict[str, dict[str, object]]:
    entries: dict[str, dict[str, object]] = {}
    offset = 0
    while offset + 110 <= len(data) and data[offset : offset + 6] in (b"070701", b"070702"):
        fields = [int(data[offset + 6 + i * 8 : offset + 14 + i * 8], 16) for i in range(13)]
        mode, size, name_size = fields[1], fields[6], fields[11]
        name_start = offset + 110
        name = data[name_start : name_start + name_size - 1].decode("utf-8", "replace")
        content_start = align(name_start + name_size, 4)
        content = data[content_start : content_start + size]
        offset = align(content_start + size, 4)
        if name == "TRAILER!!!":
            break
        entries[name] = {"mode": mode, "size": size, "sha256": digest(content)}
    return entries


def ramdisk_entries(path: Path) -> dict[str, dict[str, object]]:
    _, blobs = split_components(path.read_bytes())
    return parse_cpio(gzip.decompress(blobs["ramdisk"]))


def inspect(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    if data[:8] != b"ANDROID!":
        raise ValueError(f"Not an Android boot image: {path}")
    metadata, components = split_components(data)
    return {
        "file": path.name,
        "size": len(data),
        "sha256": digest(data),
        **metadata,
        "components": {
            name: {"size": len(blob), "sha256": digest(blob)} for name, blob in components.items()
        },
    }


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--ramdisk-diff":
        left, right = Path(sys.argv[2]), Path(sys.argv[3])
        a, b = ramdisk_entries(left), ramdisk_entries(right)
        result = {
            "added": sorted(set(b) - set(a)),
            "removed": sorted(set(a) - set(b)),
            "changed": sorted(name for name in set(a) & set(b) if a[name] != b[name]),
        }
        print(json.dumps(result, indent=2))
    else:
        print(json.dumps([inspect(Path(item)) for item in sys.argv[1:]], indent=2))
