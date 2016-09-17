# Athena LaTeX IDE

![Athena LaTeX IDE](doc/athena-latex-ide.gif?raw=true)

**LaTeX Editor for the Elementary Desktop.** Being designed particularly for Elementary OS, Athena LaTeX IDE follows [Elementary's Human Interface Guidelines](https://elementary.io/en/docs/human-interface-guidelines#concision). This means, that Athena LaTeX IDE aims to *provide an out-of-the-box experience* for writing LaTeX documents and presentations, while *avoiding tons of configurable options in favor of thoughtful design decisions*. Although Elementary OS builds on-top of Ubuntu Linux and hence you will be able to run Athena LaTeX IDE inside of an Ubuntu environment as well, note that it's only been tested with Elementary OS Freya so far. It fits very well with both, the default bright and also Elementary's alternative dark theme.

**Functionality.** The key features of Athena LaTeX IDE are:

  - Built-in support for `pdflatex`, `lualatex`, `xelatex` and `bibtex`
  - Built-in PDF preview with SyncTeX support
  - Auto-completition for `.tex` and `.bib` files and the corresponding user-defined structures (e.g. commands, BibTeX-entries, ...)
  - Intuitive session management
  - Interactive assistant for rather sophisticated project types -- like the [Metropolis Beamer Theme](https://github.com/matze/mtheme) for example, which requires the installation of additional fonts.
  - All files generated during a build -- except for the final PDF -- are kept in a hidden directory.

**Work in Progress.** See the `TODO` file for a list of known issues. Also, if you come across a new issue, please feel free to file it. Note that Athena LaTeX IDE wasn't tested with Elementary OS Loki yet.

**Motivation of the Project.** The main window's layout was roughly inspired by Texmaker. Personally, I've been using Texmaker for many years, but I felt that it's overloaded with rather useless functionalities, like SVN support, while lacking some other features at the same time. After trying to add some of those features to Texmaker, I came to the following insight: *If you're ever asked for an example of obfuscated code, point that person to Texmaker.cpp*. Without having actually checked the numbers, I'd assume that about 90% of Texmaker's source code is contained in that single file. And, even worse, there isn't any consistent code formatting or indentation at all. That was the moment, when I decided to start something new.

### Dependencies

Athena LaTeX IDE requires a number of open source projects to work properly:

* libgtksourceview-3.0-1 (>= 3.14.4)
* libxml2 (>= 2.9.1)
* libgranite3 (>= 0.3.1)
* libgtk-3-0 (>= 3.14)
* libglib2.0-0 (>= 2.32)
* libpoppler-glib8 (>= 0.24)
* libsoup2.4-1 (>= 2.44.2)

And of course Athena LaTeX IDE itself is open source.

### Credits

The source base of Athena LaTeX IDE uses a few files from other open source projects, with several modifications:

* [SyncTeX 1.16](http://itexmac.sourceforge.net/SyncTeX.html)
* [Scratch Text Editor 2.2.1](https://launchpad.net/scratch)
* [Granite 0.3.1](https://launchpad.net/granite)

See the in-app "About"-screen for details.

### Installation

- **Recommended:** Use the `.deb` Package. Download the [latest release](https://github.com/kostrykin/athena-latex-ide/releases) and double-click the file.
- **Alternative:** Build from source for a development environment.
```sh
$ ./build.sh debug
$ cd build
$ sudo make install
```
In order to create a `.deb` package afterwards, simply run `sudo cpack ..` from within the `build` directory.

### See Also

If you're using the [Moka Icon Theme](https://github.com/snwh/moka-icon-theme), then you might be interested to know that there is a compliant icon ![Icon](https://github.com/kostrykin/moka-icon-theme/blob/ab28ce98c8455fb6633deea2fd709fd13740db8b/Moka/24x24/apps/athena-latex-ide.png?raw=true) available [here](https://github.com/kostrykin/moka-icon-theme/commit/ab28ce98c8455fb6633deea2fd709fd13740db8b).

