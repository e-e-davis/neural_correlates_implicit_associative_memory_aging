#!/bin/bash
# Directories 
RAW_DATA="data/COFA/COFA_bids/derivatives/itksnap-T1-20260529"

for SUBJ_DIR in "${RAW_DATA}"/sub-*; do
    SUBJ=$(basename "$SUBJ_DIR")
    echo "Processing $SUBJ"

    # Output dirs
    ROI_MNI_DIR="${RAW_DATA}/${SUBJ}/ROIs_MNI"
    ROI_MNI_DIR_2mm="${ROI_MNI_DIR}/2mm"
    mkdir -p "$ROI_MNI_DIR_2mm"

    for ROI in "${ROI_MNI_DIR}"/*.nii.gz; do
        ROI_NAME=$(basename "$ROI")
        echo "  Transforming $ROI_NAME"
        INPUT_MNI_FILE="${ROI_MNI_DIR}/${ROI_NAME}"
        OUT_MNI_FILE="${ROI_MNI_DIR_2mm}/${ROI_NAME%.nii.gz}_2mm.nii.gz"
	echo "INPUT FILE $INPUT_MNI_FILE"
	ResampleImage 3 "$INPUT_MNI_FILE" "$OUT_MNI_FILE" 2x2x2 0 1
	
    done
done
