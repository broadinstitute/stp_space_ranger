# How to Run Space Ranger on Terra

To run Space Ranger on Terra, use the dedicated workflow (`MAIN_WORKFLOW`). It runs **Space Ranger 4.1.0** (Docker image `jishar7/space_ranger:V4.0`).

## GitHub

GitHub repository for STP-Space_Ranger: <https://github.com/broadinstitute/stp_space_ranger>

## Required Inputs

- `cytassist_image_path` (File): Path to the CytAssist image.
- `rna_fastq_directory_path` (String): `gs://` path to the directory containing the RNA (gene expression) FASTQ files.
- `sample_id` (String): Unique identifier for the Space Ranger run.
- `sample_type` (String): `"mouse"` or `"human"`. **Required only when `transcriptome_path` and `probe_set_path` are not supplied.** Ignored if both custom paths are given.

> **Renamed inputs:** `fastq_reads_directory_path` is now `rna_fastq_directory_path`, and `sample_name` is now `rna_sample_name`. Existing Terra configurations must be updated.

## Optional Inputs (Italicized in the Terra GUI)

### Images and registration
- `he_image_path` (File): Path to the H&E image.
- `registration_json_file` (File): Path to the Loupe image registration file.

### RNA sample
- `rna_sample_name` (String): Sample name used to identify the RNA FASTQ files to process. It can be the full FASTQ sample prefix (everything before `_S<n>_L<nnn>_R<n>_001.fastq.gz`) or a partial string of it; see *Sample name matching* below. Optional: if omitted, it is detected from the RNA FASTQ directory.

### Protein (antibody capture), optional
Supply these together to process protein and RNA in one run. No index files are needed.
- `protein_fastq_directory_path` (String): `gs://` path to the directory containing the protein FASTQ files.
- `protein_sample_name` (String): Sample name used to identify the protein FASTQ files (full prefix or a partial string, same matching as `rna_sample_name`). Optional: if omitted, it is detected from the protein FASTQ directory.
- `feature_reference_csv` (File): Feature reference CSV describing the protein panel.

If `protein_fastq_directory_path` is set, `feature_reference_csv` is also required. Setting `feature_reference_csv` or `protein_sample_name` without `protein_fastq_directory_path` is an error. The workflow builds a `libraries.csv` (a Gene Expression row for the RNA FASTQs and an Antibody Capture row for the protein FASTQs, RNA first) and passes it to Space Ranger with `--libraries` and `--feature-ref`. Space Ranger does not accept protein FASTQs through `--fastqs`/`--sample`.

### Sample name matching
Space Ranger needs the exact FASTQ sample prefix, e.g. `25FC52LT4_2_0476209776_Q158_V013` for `25FC52LT4_2_0476209776_Q158_V013_S2_L002_R1_001.fastq.gz`. The workflow looks at the FASTQs in each directory and works out the sample name for you:
- **No name given:** if the directory contains exactly one sample, it is used. (For an RNA-only run with several samples in the directory and no name, `--sample` is omitted and all FASTQs are used, as before. For protein runs, a name is needed whenever a directory has more than one sample.)
- **Exact match:** a name equal to a sample prefix is used as is.
- **Partial match:** if your string is contained in exactly one sample prefix, that prefix is used.
- **No match, or more than one:** the task stops before running Space Ranger and lists the available samples.

The task log shows which sample name was used.

### Custom references
- `transcriptome_path` (String): `gs://` path to a custom transcriptome, either a `.tar.gz` archive or an uncompressed directory containing a single `reference.json`.
- `probe_set_path` (String): `gs://` path to a custom probe-set `.csv`.

`transcriptome_path` and `probe_set_path` must be supplied **together or not at all**. When both are supplied they take precedence over `sample_type`.

### Run settings
- `custom_bin_size` (Int, default = 8): Additional bin size (µm) to output alongside the 8 µm bins.
- `nucleus_segmentation` (Boolean, default = true, write without quotations): Whether to enable nucleus segmentation.
- `bam_file_save` (Boolean, default = false, write without quotations): Whether to save a BAM file.
- `cpu` (Int, default = 32): Minimum number of CPU cores required for this task.
- `memory` (Int, default = 128 GB): Minimum memory (RAM) required for this task.
- `disk_size` (Int, default = 1000 GB): Storage space required, in GB.
- `preemptible_attempts` (Int, default = 1): Number of attempts to allocate a preemptible VM for this task.
- `use_ssd` (Boolean, default = false, write without quotations):
  - `true`: SSD (faster, more expensive).
  - `false`: HDD (slower, more cost-effective).

> `use_probe_set` has been removed. A probe set is always used.

### Notes
- Unless custom paths are given, the species-specific probe set and transcriptome (human or mouse) are chosen from `sample_type`.
- All input paths must start with `gs://`. Avoid spaces in input file names.

## Outputs

### Main outputs (`space_ranger_outputs`)
Saved as `{sample_id}/<file>` as in previous versions:

- `feature_slice.h5`
- `metrics_summary.csv`
- `molecule_info.h5`
- `spatial.tar.gz`
- `binned_outputs.tar.gz`
- `web_summary.html`
- `cloupe_008um.cloupe`
- `cloupe_cell.cloupe`
- `probe_set.csv`
- `segmented_outputs.tar.gz` (not produced if `nucleus_segmentation` is false)
- `barcode_mappings.parquet`
- Optional: `cloupe_<custom_bin_size>um.cloupe` (only when `custom_bin_size` is not 8)
- Optional: `possorted_genome_bam.bam` and `possorted_genome_bam.bam.bai` (only when `bam_file_save` is true)
- `additional_outputs.tar.gz`: everything else Space Ranger produced (see below)

Optional files that Space Ranger does not produce are skipped with a warning. The run fails only if `metrics_summary.csv`, `web_summary.html`, `molecule_info.h5`, `feature_slice.h5`, `binned_outputs.tar.gz` or `spatial.tar.gz` is missing.

### Additional outputs (`additional_outputs.tar.gz`)
Anything else Space Ranger writes to `outs/` that is not listed above is bundled into `{sample_id}/additional_outputs.tar.gz`, so nothing is lost and everything stays in one place. For example, `feature_reference.csv` and the isotype normalization file from protein runs, a `.csi` BAM index for very large genomes, and other directories. The contents depend on the run; untar the file to see them. The task log lists what was included.

### Output Organization

1. Go to the **Job History** tab in the gp-stp_sequencing workspace and open the relevant job.
2. Click the link under **Submission ID** to access job details.
3. Navigate to the `{sample_id}/` directory. A typical path:

```
<bucket_name>/submissions/<submission_id>/MAIN_WORKFLOW/<workflow_id>/call-space_ranger/{sample_id}/
```

If the VM was preempted, intermediate directories (`attempt-2/`, `attempt-3/`, ...) may appear. Select the most recent attempt:

```
<bucket_name>/submissions/<submission_id>/MAIN_WORKFLOW/<workflow_id>/call-space_ranger/attempt-3/{sample_id}/
```