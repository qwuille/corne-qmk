# Third-party software

Exact revisions are recorded in `upstream.lock.json`.

- The build is based on [vial-kb/vial-qmk](https://github.com/vial-kb/vial-qmk), which is distributed under GNU GPL version 2. The upstream license remains in each disposable build checkout.
- XTIPS hardware definitions are adapted from [X-Tips/QMK-Keyboard](https://github.com/X-Tips/QMK-Keyboard). Files that carry upstream copyright or license headers retain them when copied into the build checkout. The upstream repository did not contain a top-level license at the pinned revision.
- The Corne v4.1 hardware definition is sourced from [foostan/kbd_firmware](https://github.com/foostan/kbd_firmware), including its pinned Vial-QMK submodule. Files that carry upstream copyright or license headers retain them. The wrapper repository did not contain a top-level license at the pinned revision.
- `vendor/webdfu/dfu.js` is from [devanlai/webdfu](https://github.com/devanlai/webdfu) and is distributed under the ISC license. Its license text is preserved in `vendor/webdfu/LICENSE`.
