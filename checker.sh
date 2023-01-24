#!/bin/bash

# This script prints out the APOE variants in the VCF files for manual inspection

# Author: Aditya Singh
# GitHub: aditya-88

# Variables
# The directory where the VCF files are located
VCF_DIR=$1
# The directory where the TSV files will be saved
TSV_DIR=$2 #Optional. Use the same directory as VCF_DIR if not specified.
# Get custom regex to look for VCF files
VCF_REGEX=$3 #Optional. Use the default regex if not specified.

# Print usage if no arguments provided
if [ -z $VCF_DIR ]
then
    echo "Usage: apoec.sh <VCF_DIR> <TSV_DIR> <VCF_REGEX>"
    echo "VCF_DIR: The directory where the VCF files are located."
    echo "TSV_DIR: The directory where the TSV files will be saved. Use the same directory as VCF_DIR if not specified."
    echo "VCF_REGEX: Get custom regex to filter VCF files. Use all VCF files if not specified."
    exit 1
fi

# Check of the VCF directory exists
if [ ! -d $VCF_DIR ]
then
    echo "ERROR: The VCF directory does not exist."
    exit 1
fi

# Check if TSV_DIR provided, if not, set it to VCF_DIR
if [ -z $TSV_DIR ]
then
    TSV_DIR=$VCF_DIR
fi

# Check if TSV directory exists, if not create it
if [ ! -d $TSV_DIR ]
then
    mkdir -p $TSV_DIR
fi

# Find all VCF files in the given directory using the regex if provided
if [ -z $VCF_REGEX ]
then
    VCF_FILES=$(find $VCF_DIR -type f -name "*.vcf")
else
    VCF_FILES=$(find $VCF_DIR -type f -name "*.vcf" | grep -E $VCF_REGEX)
fi

# For each VCF file run a grep command and save to the output
for VCF_FILE in $VCF_FILES
do
    # Get the sample name from the VCF file
    SAMPLE=$(basename $VCF_FILE | cut -d "." -f 1)
    echo "Processing $SAMPLE..."
    # Get the APOE variants from the VCF file
    APOE_VARIANTS=$(grep -P "^19\t44908822\||^19\t44908684" $VCF_FILE)
    # Save the APOE variants to a TSV file
    echo -e "$SAMPLE\n$APOE_VARIANTS" >> $TSV_DIR/APOE_variants.tsv
done
echo "Done!"