#!/bin/bash

base=/media/lab/bigbrains/COFA/COFA_bids/derivatives/itksnap-T1-20260529
#ls /media/lab/bigbrains/COFA/COFA_bids/derivatives/itksnap-20260422

for subdir in "${base}"/sub-*; do
    seg=$(find "$subdir" -maxdepth 1 -name "layer_002*.nii.gz" | head -n 1)


    if [ -z "$seg" ]; then
        echo "No segmentation found for $subdir"
        continue
    fi

    echo "Processing $subdir"

    mkdir -p "$subdir/ROIs"

    c3d "$seg" -thresh 1 1 1 0   -o "$subdir/ROIs/leftAnteriorHipp.nii.gz"
    c3d "$seg" -thresh 2 2 1 0   -o "$subdir/ROIs/leftPosteriorHipp.nii.gz"
    c3d "$seg" -thresh 13 13 1 0   -o "$subdir/ROIs/leftPHC.nii.gz"
    c3d "$seg" -thresh 10 10 1 0   -o "$subdir/ROIs/leftERC.nii.gz"
    c3d "$seg" -thresh 11 11 1 0   -o "$subdir/ROIs/leftBA35.nii.gz"
    c3d "$seg" -thresh 12 12 1 0   -o "$subdir/ROIs/leftBA36.nii.gz"
    c3d "$seg" -thresh 101 101 1 0   -o "$subdir/ROIs/rightAnteriorHipp.nii.gz"
    c3d "$seg" -thresh 102 102 1 0   -o "$subdir/ROIs/rightPosteriorHipp.nii.gz"
    c3d "$seg" -thresh 113 113 1 0   -o "$subdir/ROIs/rightPHC.nii.gz"
    c3d "$seg" -thresh 110 110 1 0   -o "$subdir/ROIs/rightERC.nii.gz"
    c3d "$seg" -thresh 111 111 1 0   -o "$subdir/ROIs/rightBA35.nii.gz"
    c3d "$seg" -thresh 112 112 1 0   -o "$subdir/ROIs/rightBA36.nii.gz"
    c3d "$seg" -thresh 11 12 1 0     -o "$subdir/ROIs/leftPRC.nii.gz"
    c3d "$seg" -thresh 111 112 1 0   -o "$subdir/ROIs/rightPRC.nii.gz"
    c3d "$seg" -thresh 1 2 1 0       -o "$subdir/ROIs/leftHipp.nii.gz"
    c3d "$seg" -thresh 101 102 1 0   -o "$subdir/ROIs/rightHipp.nii.gz"

done
