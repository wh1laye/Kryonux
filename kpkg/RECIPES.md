# 🍳 Writing kpkg recipes

A recipe is a plain text file with the `.kpkg` extension. kpkg reads it directly: there is no shell sourcing of the header, so a recipe cannot run code outside its build functions.

## 📁 Layout

In the recipe tree every package lives in its own directory:

```text
category/name/name-version/name-version.kpkg
```

Categories used by Kryonux: `system`, `fs`, `network`, `toolchain`, `build`, `tools`, `libs`, `boot`, `init`, `admin`.

## 🧾 Fields

| Field | Required | Meaning |
| :--- | :--- | :--- |
| `PACKAGE` | yes | Package name |
| `VERSION` | yes | Package version |
| `DESCRIPTION` | yes | One line description |
| `LICENSE` | yes | License identifier |
| `SRC_URI` | yes | Source URLs, separated by spaces. Use `url -> name` to rename a download |
| `HOMEPAGE` | no | Project website |
| `DEPEND` | no | Build dependencies |
| `RDEPEND` | no | Runtime dependencies |
| `SLOT` | no | Slot name for parallel versions |
| `BUILD_FLAGS` | no | Per-recipe build options |

Values may span several lines inside double quotes.

## 🔧 Build functions

| Function | Legacy name | Runs |
| :--- | :--- | :--- |
| `prepare` | `src_prepare` | After unpacking, before configuring |
| `configure` | `src_configure` | Before building |
| `build` | `src_compile` | Compiles the sources |
| `install` | `src_install` | Installs into `$DESTDIR` |
| `pre_install` | `pkg_preinst` | Before files reach the system |
| `post_install` | `pkg_postinst` | After files reach the system |
| `pre_remove` | `pkg_prerm` | Before removal |
| `post_remove` | `pkg_postrm` | After removal |

Both spellings work. Each function may appear once.

## 📄 Example

```text
PACKAGE=hello
VERSION=1.0
DESCRIPTION="Example package"
LICENSE="GPL-3.0"
SRC_URI="https://example.org/hello-1.0.tar.gz"

configure() {
  ./configure --prefix=/usr
}
build() {
  make
}
install() {
  make DESTDIR="$DESTDIR" install
}
```

## ✅ Checking and installing a recipe

```sh
kpkg lint hello-1.0.kpkg
doas kpkg install ./hello-1.0.kpkg
```

`kpkg lint` reports missing fields and syntax errors. `kpkg install` accepts a path to a `.kpkg` file directly; its dependencies are still resolved from the recipe tree. Packages installed this way are recorded in the category `local`.
