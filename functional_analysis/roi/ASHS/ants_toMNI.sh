#!/bin/bash
# Directories -- ANTS RUN IN NEURODESK
RAW_DATA="data/COFA/COFA_bids/derivatives/itksnap-T1-20260529"
FMRIPREP="data/COFA/COFA_bids/derivatives/fmriprep_slicetime"

for SUBJ_DIR in "${RAW_DATA}"/sub-*; do
    SUBJ=$(basename "$SUBJ_DIR")
    echo "Processing $SUBJ"

    # Input images
    # T1 image used in itksnap 
    T1_FILE=$(ls "${RAW_DATA}/${SUBJ}"/layer_001_*.nii.gz 2>/dev/null | head -1)
    # MNI space template from fmriprep 
    MNI_TEMPLATE="${FMRIPREP}/${SUBJ}/anat/${SUBJ}_space-MNI152NLin2009cAsym_desc-preproc_T1w.nii.gz"
    #uses precomputed warp from fMRIPrep 
    FMRIPREP_XFM="${FMRIPREP}/${SUBJ}/anat/${SUBJ}_from-T1w_to-MNI152NLin2009cAsym_mode-image_xfm.h5"

    if [[ -z "$T1_FILE" ]]; then
        echo "WARNING: No T1 found for $SUBJ, skipping"
        continue
    fi

    if [[ ! -f "$FMRIPREP_XFM" ]]; then
        echo "WARNING: No fMRIPrep transform found for $SUBJ, skipping"
        continue
    fi

    # Output dirs
    ROI_DIR="${RAW_DATA}/${SUBJ}/ROIs"
    ROI_MNI_DIR="${RAW_DATA}/${SUBJ}/ROIs_MNI"
    mkdir -p "$ROI_MNI_DIR"

    for ROI in "${ROI_DIR}"/*.nii.gz; do
        ROI_NAME=$(basename "$ROI")
        echo "  Transforming $ROI_NAME"
        OUT_MNI_FILE="${ROI_MNI_DIR}/${ROI_NAME%.nii.gz}_space-MNI.nii.gz"

        antsApplyTransforms -d 3 \
            -i "$ROI" \
            -r "$MNI_TEMPLATE" \
            -o "$OUT_MNI_FILE" \
            -n NearestNeighbor \
            -t "$FMRIPREP_XFM"
    done
done
