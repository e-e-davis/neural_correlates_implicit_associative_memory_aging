import glob
import os

for file in glob.glob('raw_data/sub-*/anat/*defaced*'):
	os.rename(file, file.replace('_defaced', ''))
