# EXS24 For Renoise

This is a renoise tool that adds support for the Logic EXS24 sample format.

## Installation

## Usage

Once the tool is installed .exs instruments should be visible in the sidebar.  Clicking on the instrument will load it just like a native renoise instrument.

The tool will attempt to load the samples automatically.  If the sample path cannot be determined you will be prompted to select the folder.

This tool can currently map the following properties for zones and samples:

- name
- fine tune
- panning
- oneshot
- base note
- note range
- velocity range
- loop start
- loop end
- loop reverse

## Packaging

```
$ zip -vr com.matta.exs24.xrnx * -x@./exclude.list
```