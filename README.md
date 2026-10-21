# Evaluating Precipitation Datasets in Czechia

Bachelor's thesis project | Environmental Data Science | Czech University of Life Sciences Prague (2025)

## Project overview

For my bachelor's thesis, I compared gridded precipitation datasets with rain gauge observations across Czechia to investigate how accurately they represent measured precipitation. I focused on whether finer spatial resolution led to better agreement with observations, and how differences varied by season, elevation, and time period.

The analysis used **146 rain gauge stations** and the **1990–2009** period, comparing the **EMO-1** gridded dataset at several aggregated spatial resolutions and **E-OBS** with observations from the Czech Hydrometeorological Institute (CHMI).

## Tools and methods

- **R:** data cleaning and transformation with `dplyr`/`tidyverse`; NetCDF processing with `ncdf4`; date handling with `lubridate`; visualisation with `ggplot2`.
- **Climate Data Operators (CDO) and Bash:** preprocessing and extracting gridded precipitation values corresponding to station locations.
- **Analysis:** annual precipitation totals, percentage relative bias, boxplots, seasonal comparisons, elevation-based comparisons, and comparisons between 1990–1999 and 2000–2009.

## Main findings

- Increasing the spatial resolution of EMO-1 did **not** produce a significant overall improvement in precipitation accuracy in this study.
- Biases tended to be larger at higher elevations, especially under challenging winter conditions.
- Winter precipitation estimates showed particularly pronounced biases; spring and autumn generally showed smaller discrepancies.
- Bias variability was lower in the 2000–2009 period than in 1990–1999, although discrepancies remained.

These findings are based on the submitted thesis. The analysis covered two gridded products and used relative bias as its main evaluation measure, so they should not be generalized to every precipitation product or accuracy metric.

## Repository contents

- `thesis_analysis.R` — original R script for processing station and gridded data, calculating comparisons, and generating plots.
- `figures/` — selected thesis visualisations.

## Data and reproducibility

This repository documents the original research workflow. The R script contains machine-specific file paths and depends on external rain gauge and gridded NetCDF datasets, plus preprocessing performed with CDO/Bash. **It has not been repackaged or re-tested as an end-to-end reproducible pipeline.** Source data are not redistributed here; consult the original data providers and their licensing terms.

## Context

This project was completed as academic research. Its main purpose in this portfolio is to demonstrate hands-on experience working with real datasets, data preparation, joins and aggregation, statistical comparisons, and communicating analytical findings.
