# Help4 Brand Asset Provenance

The cPanel and WHM plugin icons use the official H4 mark published in the Help4 Network website logo.

- Source: `https://help4network.com/assets/img/logo.png`
- Retrieved: 2026-07-21
- Source SHA-256: `dd9076c6cbac05e7ef22b47c5bb0cb050fdb480e081b2f4f07f6b81bdee04685`
- Packaged PNG SHA-256: `69cd9fd4a616191e8d33440a1d4e69fa38ee00050bba209815eb7821cec9f31e`

The 48x48 PNG is the left 185x185 H4 mark cropped from the published 544x185 transparent logo and resized with Lanczos filtering. The Jupiter SVG embeds that exact packaged PNG so cPanel and WHM show the same mark.

Rebuild command:

```bash
curl -fsSL https://help4network.com/assets/img/logo.png -o /tmp/help4network-logo.png
ffmpeg -hide_banner -loglevel error -y \
  -i /tmp/help4network-logo.png \
  -vf "crop=185:185:0:0,scale=48:48:flags=lanczos,format=rgba" \
  -frames:v 1 src/static/help4-disk-usage.png
```
