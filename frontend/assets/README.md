# Brand assets

`logo.svg` is the bundled vector logo and is what the app currently displays.

## Using your own PNG instead

Drop a square PNG at `assets/logo.png` and the app will prefer it automatically (the `BrandLogo` widget falls back to the SVG if the PNG isn't present). Recommended sizes:

- 512×512 minimum for crisp rendering on tablets.
- Transparent background, so it adapts to light/dark themes.

After dropping the file, restart `flutter run` so the asset bundle picks it up.
