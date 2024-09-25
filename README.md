# APOE Genotype Coding #

[![DOI](https://zenodo.org/badge/583294262.svg)](https://zenodo.org/doi/10.5281/zenodo.13837763)

## Introduction ##

This small piece of nifty script takes in a folder of VCF/ VCF.gz files and genotypes APOE. In the end, we have a single report file with the name of sample and the genotype.

## Requirements ##

The script is written in shell script and requires only `BCFTools` to be installed on the system apart from some default tools such as `awk`/ `sed`/ `grep` etc.
The script only supports Linux/ Unix/ macOS

## Usage ###

```text
Usage: apoec.sh <VCF_DIR> <TSV_DIR> <VCF_REGEX>
VCF_DIR: The directory where the VCF files are located.
TSV_DIR: The directory where the TSV files will be saved. Use the same directory as VCF_DIR if not specified.
VCF_REGEX: Get custom regex to filter VCF/VCF.gz files. Use all VCF/ VCF.gz files if not specified.
```

## Limitation ##

Currently only supports GRCh38, but, will add GRCh37 support later.
