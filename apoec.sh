#!/bin/bash
# Author: Aditya Singh
# GitHub: https://github.com/aditya-88
# This script does the following:
# A. Find all VCF files in the given directory
# B. For each VCF file, extract CHR-POS-REF-ALT and save as a TSV file
# C. Perform the genotyping
# D. Compile a report of all samples in a single file

# This script requires the following software:
# bcftools
# Exit on error from any part of the script
set -eE
# Exit the entire script if any command in a pipe fails
set -o pipefail
# Exit the entire script if ctrl-c is pressed
trap "exit" INT
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
    echo "VCF_REGEX: Get custom regex to filter VCF/VCF.gz files. Use all VCF/ VCF.gz files if not specified."
    exit 1
fi

# Check of the VCF directory exists
if [ ! -d $VCF_DIR ]
then
    echo "ERROR: The VCF directory does not exist."
    exit 1
fi

# Check if bcftools is installed
if ! command -v bcftools &> /dev/null
then
    echo -e "ERROR: bcftools is not installed.\If this is a SLURM cluster, please load the bcftools module.\nIf this is not a SLURM cluster, please install bcftools."
    exit 1
fi

# APOE genotypes for GRCh38
rs7412="19-44908822-C-T"
rs429358="19-44908684-T-C"
WILD_rs7412="19-44908822-C-C"
WILD_rs429358="19-44908684-T-T"

# Check if TSV_DIR provided, if not, set it to VCF_DIR
if [ -z $TSV_DIR ]
then
    TSV_DIR=$VCF_DIR
fi
# Check if the TSV directory exists, if not create it
if [ ! -d $TSV_DIR ]
then
    mkdir -p $TSV_DIR
fi
# Check if final result file exists, if yes, read it
if [ -f $TSV_DIR/APOE_genotype_report.tsv ]
then
    echo "Reading the final result file..."
    # Read the final result file
    while IFS=$'\t' read -r -a line
    do
        # Skip the header
        if [[ ${line[0]} == "SampleID" ]]
        then
            continue
        fi
        # Get the sample ID
        SAMPLE_ID=${line[0]}
        # Get the APOE genotype
        APOE_GENOTYPE=${line[1]}
        # Add the sample ID and APOE genotype to the array
        APOE_GENOTYPE_ARRAY+=("$SAMPLE_ID" "$APOE_GENOTYPE")
    done < $TSV_DIR/APOE_genotype_report.tsv
else
    # Create an empty final report file
    echo "SampleID	APOE_genotype" > $TSV_DIR/APOE_genotype_report.tsv
fi

# A. Find all VCF or vcf.gz files in the given directory
echo "Finding all VCF/VCF.gz files in the input directory..."
if [ -z $VCF_REGEX ]
then
    VCF_FILES=$(find $VCF_DIR -type f -name "*.vcf" -o -name "*.vcf.gz")
else
    VCF_FILES=$(find $VCF_DIR -type f -name "*.vcf" -o -name "*.vcf.gz" | grep -E $VCF_REGEX)
fi
# Print the number of files found
echo "Found $(echo $VCF_FILES | wc -w) VCF files."

# Check if any VCF files were found
if [ -z "$VCF_FILES" ]
then
    echo "ERROR: No VCF files found in \"$VCF_DIR\"."
    exit 1
fi
# B. For each VCF file, extract CHR-POS-REF-ALT and save as a TSV file
for VCF_FILE in $VCF_FILES
do
    # Skip the file if it is empty and notify the user
    if [ ! -s $VCF_FILE ]
    then
        echo "WARNING: $VCF_FILE is empty. Skipping..."
        continue
    fi
    # Setup original file name
    VCF_FILE_ORIG=$VCF_FILE
    # Get the file name
    FILE_NAME=$(basename $VCF_FILE)
    # Get the file name without the extension
    FILE_NAME_NO_EXT=${FILE_NAME%.*}
    echo "Processing $FILE_NAME_NO_EXT..."
    # Check if this sample ID has already been processed
    if [[ " ${APOE_GENOTYPE_ARRAY[@]} " =~ " $FILE_NAME_NO_EXT " ]]
    then
        echo "WARNING: $FILE_NAME_NO_EXT has already been processed. Skipping..."
        continue
    fi

    # Get the TSV file name
    TSV_FILE=$TSV_DIR/$FILE_NAME_NO_EXT.tsv
    # Check if the input file is compressed, if so, decompress it without deleting the original
    if [[ $VCF_FILE == *.gz ]]
    then
        echo "Decompressing $FILE_NAME_NO_EXT..."
        gunzip -c $VCF_FILE > $TSV_DIR/$FILE_NAME_NO_EXT
        VCF_FILE=$TSV_DIR/$FILE_NAME_NO_EXT
    fi
    #Subset the input VCF file to only include the chromosome 19
    echo "Subsetting $FILE_NAME_NO_EXT to only include chromosome 19..."
    grep '^#\|^19\|^chr19' $VCF_FILE > $TSV_DIR/$FILE_NAME_NO_EXT.chr19.vcf
    VCF_FILE=$TSV_DIR/$FILE_NAME_NO_EXT.chr19.vcf
    # Remove "chr" from the chromosome names
    # Check if mawk is installed, if so use it otherwise, use awk
    echo "Removing \"chr\" from the chromosome names..."
    if command -v mawk &> /dev/null
    then
        mawk '$0 == "^#" gsub("chr","") {print $0}; $0 == "^chr" {gsub(/^chr/, "")}{print $0}' "$VCF_FILE" > $TSV_DIR/$FILE_NAME_NO_EXT.no_chr
    else
        echo "Using awk..."
        awk '$0 == "^#" gsub("chr","") {print $0}; $0 == "^chr" {gsub(/^chr/, "")}{print $0}' "$VCF_FILE" > $TSV_DIR/$FILE_NAME_NO_EXT.no_chr
    fi

    # Test if the previous command was successful
    if [ ! -s $TSV_DIR/$FILE_NAME_NO_EXT.no_chr ]
    then
        echo "ERROR: $TSV_DIR/$FILE_NAME_NO_EXT.no_chr is empty. Skipping..."
        continue
    fi
    # Replace the original VCF file with the one without "chr"
    rm "$VCF_FILE"
    VCF_FILE="$TSV_DIR/$FILE_NAME_NO_EXT.no_chr"
    # Check if output file is empty
    if [ ! -s $VCF_FILE ]
    then
        echo "ERROR: $VCF_FILE is empty. No chromosome 19 was found in the input VCF file."
        continue
    fi
    # Split multi-alleleic sites into multiple lines
    bcftools norm --threads "$(nproc)" -m - $VCF_FILE > $TSV_DIR/$FILE_NAME_NO_EXT.split
    # Extract CHR-POS-REF-ALT- and save as a TSV file
    bcftools query -f '%CHROM-%POS-%REF-%ALT-[%GT]\n' $TSV_DIR/$FILE_NAME_NO_EXT.split > $TSV_FILE
    # Check if output file is empty
    if [ ! -s $TSV_FILE ]
    then
        echo "ERROR: $TSV_FILE is empty. Skipping..."
        continue
    fi
    # Check which APOE genotypes are present
    if grep -q $rs7412 $TSV_FILE
    then
        grep $rs7412 $TSV_FILE > $TSV_DIR/$FILE_NAME_NO_EXT.APOE
    else
        echo $WILD_rs7412-1/1 > $TSV_DIR/$FILE_NAME_NO_EXT.APOE
    fi
    if grep -q $rs429358 $TSV_FILE
    then
        grep $rs429358 $TSV_FILE >> $TSV_DIR/$FILE_NAME_NO_EXT.APOE
    else
        echo $WILD_rs429358-1/1 >> $TSV_DIR/$FILE_NAME_NO_EXT.APOE
    fi

    # Get zygosity
    sed -e 's/1\/1/HOM/g' -e 's/0\/1/HET/g' -e 's/1\/0/HET/g' "$TSV_DIR/$FILE_NAME_NO_EXT".APOE > $TSV_DIR/"$FILE_NAME_NO_EXT".APOE_renamed

    # Perform genotype checks for all possible combinations of APOE and WILD genotypes
    if grep -q $WILD_rs7412-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $WILD_rs429358-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-3/3" >> $TSV_DIR/APOE_genotype_report.tsv

    elif grep -q $WILD_rs7412-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-4/4" >> $TSV_DIR/APOE_genotype_report.tsv

    elif grep -q $WILD_rs7412-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-3/4" >> $TSV_DIR/APOE_genotype_report.tsv
        
    elif grep -q $WILD_rs429358-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs7412-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-2/3" >> $TSV_DIR/APOE_genotype_report.tsv
    
    elif grep -q $WILD_rs429358-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs7412-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-2/3" >> $TSV_DIR/APOE_genotype_report.tsv

    elif grep -q $rs7412-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-1/1" >> $TSV_DIR/APOE_genotype_report.tsv

    elif grep -q $rs7412-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-1/3" >> $TSV_DIR/APOE_genotype_report.tsv

    elif grep -q $rs7412-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-1/4" >> $TSV_DIR/APOE_genotype_report.tsv

    elif grep -q $rs7412-HOM $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-1/2" >> $TSV_DIR/APOE_genotype_report.tsv
    elif grep -q $rs7412-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed && grep -q $rs429358-HET $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    then
        echo -e "$FILE_NAME_NO_EXT\tAPOE-2/4" >> $TSV_DIR/APOE_genotype_report.tsv
    else
        echo -e "$FILE_NAME_NO_EXT\tAPOE_unknown" >> $TSV_DIR/APOE_genotype_report.tsv
    fi
    # Remove interim files
    rm $TSV_DIR/$FILE_NAME_NO_EXT.split
    rm $TSV_FILE
    rm $TSV_DIR/$FILE_NAME_NO_EXT.APOE
    rm $TSV_DIR/$FILE_NAME_NO_EXT.APOE_renamed
    # Check if VCF file in the TSV_DIR, if so, delete it
    if [ -f $TSV_DIR/$FILE_NAME_NO_EXT ]
    then
        rm $TSV_DIR/$FILE_NAME_NO_EXT
    fi
    # Remove VCF file if it was decompressed
    if [ $VCF_FILE != $VCF_FILE_ORIG ]
    then
        rm $VCF_FILE
    fi
done

