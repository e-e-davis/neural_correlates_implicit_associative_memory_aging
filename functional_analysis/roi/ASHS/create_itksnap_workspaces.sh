#!/bin/bash
# Path to ITK-SNAP workspace tool
ITKSNAP_WT="/home/lab/itksnap-4.4.0-20250909-Linux-x86_64/bin/itksnap-wt"

# Folder with raw data
RAW_DATA="raw_data"

# Base output folder for ITK-SNAP workspaces
OUTPUT_BASE="derivatives/itksnap-T1-20260529"

# Loop over all participants
for SUBJ_DIR in $RAW_DATA/sub-*; do
    SUBJ=$(basename $SUBJ_DIR)

    T1_FILE="$SUBJ_DIR/anat/${SUBJ}_T1w.nii.gz"

    # Create a folder for the subject inside the output directory
    OUTPUT_SUBJ_DIR="$OUTPUT_BASE/$SUBJ"
    mkdir -p "$OUTPUT_SUBJ_DIR"
    OUTPUT_FILE="$OUTPUT_SUBJ_DIR/mywork.itksnap"

    # Check that T1 exists
    if [[ -f "$T1_FILE"  ]]; then
        echo "Creating workspace for $SUBJ..."
        $ITKSNAP_WT \
            -layers-add-anat "$T1_FILE" -tags-add T1-MRI \
            -o "$OUTPUT_FILE"
    else
        echo "Skipping $SUBJ: T1 file missing"
    fi
done
