![GH Language](https://img.shields.io/github/languages/top/pforret/progressbar)
![GH stars](https://img.shields.io/github/stars/pforret/progressbar)
![GH tag](https://img.shields.io/github/v/tag/pforret/progressbar)
![GH License](https://img.shields.io/github/license/pforret/progressbar)
[![basher install](https://img.shields.io/badge/basher-install-white?logo=gnu-bash&style=flat)](https://basher.gitparade.com/package/)

# progressbar

Show a CLI progress bar for long running scripts

## Installation

with [basher](https://github.com/basherpm/basher)

	$ basher install pforret/progressbar

or with `git`

	$ git clone https://github.com/pforret/progressbar.git
	$ cd progressbar

## Usage

    Program: progressbar 1.0.0 by peter@forret.com
    Updated: Dec  1 14:39:22 2020
    Usage: progressbar [-h] [-q] [-v] [-f] [-l <log_dir>] [-t <tmp_dir>] [-i <infile>] [-o <outfile>] [-b <barformat>] <action> <input>
    Flags, options and parameters:
        -h|--help      : [flag] show usage [default: off]
        -q|--quiet     : [flag] no output [default: off]
        -v|--verbose   : [flag] output more [default: off]
        -f|--force     : [flag] do not ask for confirmation (always yes) [default: off]
        -l|--log_dir <val>: [optn] folder for log files   [default: log]
        -t|--tmp_dir <val>: [optn] folder for temp files  [default: /tmp/progressbar]
        -b|--barformat <val>: [optn] format of bar: normal/half/long/short  [default: normal]
        <action>  : [parameter] lines/seconds
        <input>   : [parameter] input number or operation identifier
        
## Example

    # simplest use: when the approx number of lines output is known
    # e.g. first do a rsync --dry-tun to check how many files have to be trasferred
    # and then use this number in the actual operation
    $cexpected_lines=$(rsync --dry-run <from> <to> | awk 'END {print NR}')
    $ rsync <from> <to> | progressbar lines "$expected_lines"
    
    # or use it with 'auto-estimate'
    # the first time the script learns the expected # lines/seconds for operation '40-pings-to-google'
    $ ping -c 40 www.google.com | ./progressbar lines 40-pings-to-google
    45 lines / 39 secs …
    
    # the following times, it can use this information to show a 0-100% progressbar
    $ ping -c 40 www.google.com | ./progressbar lines 40-pings-to-google
    [0---------1---------2---------3---------4---------5---------6---------7---------8---------9---------!] 100% / 39 secs     
    
    # can also be used with different progress bar format (here: short)
    $ ping -c 40 www.google.com | ./progressbar -b short lines 40-pings-to-google
    [----------] 100% / 39 secs    
    
    
## Acknowledgements

* script created with [bashew](https://github.com/pforret/bashew)

&copy; 2020 Peter Forret
