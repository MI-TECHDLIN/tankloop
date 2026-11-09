# Third-party fonts and icons

The design system bundles the files below. Each license text ships in `assets/licenses/` and is registered with Flutter's license page by `registerTankLoopLicenses()`. Material Symbols comes from the `material_symbols_icons` pub package, whose Apache 2.0 license Flutter adds to the generated notices automatically.

| Asset | Role | Source | License | SHA-256 |
| --- | --- | --- | --- | --- |
| `assets/fonts/PlusJakartaSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf` | Interface and heading type | [tokotype/PlusJakartaSans](https://github.com/tokotype/PlusJakartaSans) `fonts/ttf` at `18d1cd2` | SIL OFL 1.1 (`PlusJakartaSans-OFL.txt`) | see below |
| `assets/fonts/PlayfairDisplay-Variable.ttf` | `tankloop` wordmark | [Google Fonts](https://github.com/google/fonts/tree/main/ofl/playfairdisplay) | SIL OFL 1.1 (`PlayfairDisplay-OFL.txt`) | `c40f2293766a503bc70cce9e512ef844a4ccb7cbcde792fe2ea31d191917d8d6` |
| `assets/icons/Phosphor-Duotone.ttf` | Evidence and feature accents | npm [`@phosphor-icons/web@2.1.2`](https://www.npmjs.com/package/@phosphor-icons/web) `src/duotone/Phosphor-Duotone.ttf` | MIT (`Phosphor-MIT.txt`) | `80e6f0d6fa8ce96a9933f48aaabddc592c5d2b52caf8f010a7e54a17c74084bf` |
| `assets/icons/Lucide.ttf` | Quiet metadata | npm [`lucide-static@1.59.0`](https://www.npmjs.com/package/lucide-static) `font/lucide.ttf` | ISC, with MIT for Feather-derived glyphs (`Lucide-ISC.txt`) | `387dd5a1c10fc24701551f1f19d9384f4b871a799d78284d46f6bdc4205a54bd` |

Plus Jakarta Sans checksums: Regular `bd6276d4060e3b1ebc45047469e0bb86b08f301ba681cdf1ceb6245ea10478d2`, Medium `c77bab757d7402ec6d9341d5f7ddaafb2474e17026792697ba4624c7dc89caf7`, SemiBold `65dbcedb6596a41c30869729eb31cb57d1f5edfe365684314bba8a1994eaa4cb`, Bold `5f5342ef76862b5b5365d1dff1a667629dfa484e388dd602552f647219c3870f`, ExtraBold `7d60d21b5dec501c77437e80aabd539f1d7a7b0ac7d4ada361d4d42abc7c55ea`.

The published Flutter wrappers for Phosphor (`phosphor_flutter` 2.1.0) and Lucide (`lucide_icons` 0.257.0) subclass `IconData`, which is a `final` class in the supported Flutter release, so the upstream fonts are bundled directly. `TankGlyphs` maps each code point from the package's own stylesheet or `codepoints.json`. To add a glyph, look it up in the same release and keep every `IconData` constant so release builds can tree-shake the fonts.

The asset pictograms, layered record artwork and network diagram are original TankLoop drawings in `lib/src/artwork.dart`.
