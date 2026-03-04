import sys
import os
import io

def crop_to_square(img):
    """Center crop para quadrado, preservando o centro da imagem."""
    w, h = img.size
    side = min(w, h)
    left   = (w - side) // 2
    top    = (h - side) // 2
    return img.crop((left, top, left + side, top + side))

def fix_apic(folder):
    try:
        from mutagen.id3 import ID3, APIC
    except ImportError:
        print("[ERRO] mutagen nao encontrado. Instale com: pip install mutagen")
        sys.exit(1)

    try:
        from PIL import Image
    except ImportError:
        print("[ERRO] Pillow nao encontrado. Instale com: pip install pillow")
        sys.exit(1)

    mp3_files = [f for f in os.listdir(folder) if f.lower().endswith(".mp3")]

    if not mp3_files:
        print(f"Nenhum arquivo MP3 encontrado em: {folder}")
        return

    fixed = 0
    skipped = 0

    for filename in mp3_files:
        filepath = os.path.join(folder, filename)
        try:
            tags = ID3(filepath)
            apic_keys = [k for k in tags.keys() if k.startswith("APIC")]

            if not apic_keys:
                print(f"  [SEM ARTWORK] {filename}")
                skipped += 1
                continue

            apic = tags[apic_keys[0]]
            img = Image.open(io.BytesIO(apic.data))

            # Converte para RGB (remove canal alpha se houver)
            if img.mode in ("RGBA", "P", "LA"):
                img = img.convert("RGB")

            # Center crop para quadrado (corrige thumbnails 16:9 do YouTube)
            img = crop_to_square(img)

            # Redimensiona para 800x800 (máximo suportado pelos CDJs Pioneer)
            img = img.resize((800, 800), Image.LANCZOS)

            # Salva como JPEG com DPI=300 (requisito do RekordBox)
            output = io.BytesIO()
            img.save(output, format="JPEG", quality=90, dpi=(300, 300))

            # Remove todas as APICś existentes e reembute a corrigida
            for key in apic_keys:
                del tags[key]

            tags.add(APIC(
                encoding=3,
                mime="image/jpeg",
                type=3,   # Cover (Front)
                desc="",
                data=output.getvalue()
            ))

            tags.save(v2_version=3)
            print(f"  [OK] Corrigido: {filename}")
            fixed += 1

        except Exception as e:
            print(f"  [ERRO] {filename}: {e}")

    print()
    print(f"Concluido: {fixed} corrigidos, {skipped} sem alteracao.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python fix_artwork.py \"C:\\caminho\\pasta\"")
        sys.exit(1)
    fix_apic(sys.argv[1])