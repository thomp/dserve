# dserve

*Use dired to make files available via HTTP.*

---

## Getting started

1. Download `dserve.el`.

2. Ensure the `elnode` and `seq` packages are loaded.

2. Ensure Emacs loads `dserve.el`. For example, you might add the following line to your `~/.emacs`:
   `(load "/path/to/dserve.el")`


## Use

1. Start the HTTP server:

   <kbd>M-x</kbd> `dserve-start`

2. Add the file(s) of interest using dired

   <kbd>M-x</kbd> `dired`

   [select/tag/mark files]

   <kbd>M-x</kbd> `dserve-add-files`



## Miscellany

- If you are unsure of the HTTP server details, obtain IP and port information with

   <kbd>M-x</kbd> `dserve-where-serving`


- If you want to be able to access the dserve page from another device, ensure your firewall allows accepting TCP connections on the port you intend to use.


## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

If you did not receive a copy of the GNU General Public License along with this program, see http://www.gnu.org/licenses/.
