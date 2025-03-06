A sample of personal scripts by Benjamin A Philip

Not designed for GitHub/sharing, but now archived & visible here.

This scripts represent the core analysis pipeline for project "10_Connectivity":
1) EVmaker_STEGAMRI: create EV files from behavioral data. There is also a version in NRL-misc.

2) compareRaters10: combines manual video-coding results (Lego task) by 2 raters into a single ZZ file that the raters can use to create & record consensus

> borisAnalyze09 is called by #2, extracts data from Excel sheet saved by a rater

3) legoAnalyze10: collects the results of Lego data after consensus

4) STEGAMRI_decode_runner: analyze & organize STEGA (drawing) data, integrates with results of legoAnalyze10, and saves excel outputs that get passed to MRI analysis software (fMRIprep, FSL)

> STEGAMRI_decode is called by #4, pulls data from a single STEGA run

5) roiAnalysis10: after MRI analysis, uses behavioral data to predict brain activity in a prior regions of interest





