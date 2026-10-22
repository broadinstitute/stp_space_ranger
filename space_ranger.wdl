version 1.0

task space_ranger {

    input {
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file

        String rna_fastq_directory_path
        String rna_sample_name

        File? feature_reference_csv

        # Empty when not supplied.
        String protein_fastq_directory_path

        # "None" when not supplied.
        String protein_sample_name

        # Empty when not supplied.
        #
        # Required only when custom transcriptome_path and
        # probe_set_path are not supplied.
        String sample_type

        # Empty when not supplied.
        #
        # Otherwise, must be one of:
        #   gs://bucket/reference.tar.gz
        #   gs://bucket/uncompressed-reference-directory/
        String transcriptome_path

        # Empty when not supplied.
        #
        # Otherwise, must be a gs:// path to a probe-set CSV.
        String probe_set_path

        String sample_id
        Boolean bam_file_save

        Int disk_size
        Int cpu
        Boolean use_ssd
        Int memory
        Int preemptible_attempts
        Int custom_bin_size

        Boolean nucleus_segmentation
    }

    command <<<
        #!/bin/bash

        set -euo pipefail
        IFS=$'\n\t'

        SAMPLE_ID="~{sample_id}"
        RNA_SAMPLE_NAME="~{rna_sample_name}"
        PROTEIN_SAMPLE_NAME="~{protein_sample_name}"
        SAMPLE_TYPE="~{sample_type}"

        RNA_FASTQ_SOURCE="~{rna_fastq_directory_path}"
        PROTEIN_FASTQ_SOURCE="~{protein_fastq_directory_path}"
        FEATURE_REF_PATH="~{if defined(feature_reference_csv) then select_first([feature_reference_csv]) else ""}"
        TRANSCRIPTOME_SOURCE="~{transcriptome_path}"
        PROBE_SET_SOURCE="~{probe_set_path}"

        HE_IMAGE_PATH="~{if defined(he_image_path) then select_first([he_image_path]) else ""}"
        REGISTRATION_JSON_PATH="~{if defined(registration_json_file) then select_first([registration_json_file]) else ""}"

        BAM_FILE_SAVE="~{bam_file_save}"
        NUCLEUS_SEGMENTATION="~{nucleus_segmentation}"
        CUSTOM_BIN_SIZE="~{custom_bin_size}"

        WORK_ROOT="${PWD}"

        RNA_FASTQ_LOCAL_DIR="${WORK_ROOT}/fastqs/rna"
        PROTEIN_FASTQ_LOCAL_DIR="${WORK_ROOT}/fastqs/protein"
        TRANSCRIPTOME_STAGING_DIR="${WORK_ROOT}/transcriptome"
        INPUT_STAGING_DIR="${WORK_ROOT}/input_files"

        mkdir -p \
            "${RNA_FASTQ_LOCAL_DIR}" \
            "${TRANSCRIPTOME_STAGING_DIR}" \
            "${INPUT_STAGING_DIR}"

        # ------------------------------------------------------------
        # Default reference paths
        # ------------------------------------------------------------

        DEFAULT_MOUSE_TRANSCRIPTOME="gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_references/mouse/refdata-gex-mm10-2020-A.tar.gz"

        DEFAULT_HUMAN_TRANSCRIPTOME="gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_references/human/refdata-gex-GRCh38-2020-A.tar.gz"

        DEFAULT_MOUSE_PROBE_SET="gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_probe_sets/mouse/Visium_Mouse_Transcriptome_Probe_Set_v2.0_mm10-2020-A.csv"

        DEFAULT_HUMAN_PROBE_SET="gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_probe_sets/human/Visium_Human_Transcriptome_Probe_Set_v2.0_GRCh38-2020-A.csv"

        # ------------------------------------------------------------
        # Resolve custom versus default references
        # ------------------------------------------------------------

        if [[ -n "${TRANSCRIPTOME_SOURCE}" ]] && \
           [[ -z "${PROBE_SET_SOURCE}" ]]; then

            echo "ERROR: transcriptome_path was provided without probe_set_path."
            echo "Custom transcriptome and probe-set paths must be supplied together."
            exit 1
        fi

        if [[ -z "${TRANSCRIPTOME_SOURCE}" ]] && \
           [[ -n "${PROBE_SET_SOURCE}" ]]; then

            echo "ERROR: probe_set_path was provided without transcriptome_path."
            echo "Custom transcriptome and probe-set paths must be supplied together."
            exit 1
        fi

        if [[ -n "${TRANSCRIPTOME_SOURCE}" ]] && \
           [[ -n "${PROBE_SET_SOURCE}" ]]; then

            echo "Using the supplied custom transcriptome and probe set."

            if [[ -n "${SAMPLE_TYPE}" ]]; then
                echo "sample_type was also supplied but will be ignored"
                echo "because custom reference paths take precedence."
            fi

        else
            echo "No custom reference paths were supplied."
            echo "Selecting default references using sample_type."

            case "${SAMPLE_TYPE}" in
                human)
                    TRANSCRIPTOME_SOURCE="${DEFAULT_HUMAN_TRANSCRIPTOME}"
                    PROBE_SET_SOURCE="${DEFAULT_HUMAN_PROBE_SET}"
                    ;;

                mouse)
                    TRANSCRIPTOME_SOURCE="${DEFAULT_MOUSE_TRANSCRIPTOME}"
                    PROBE_SET_SOURCE="${DEFAULT_MOUSE_PROBE_SET}"
                    ;;

                "")
                    echo "ERROR: No custom reference paths or sample_type were provided."
                    echo
                    echo "Provide both transcriptome_path and probe_set_path,"
                    echo 'or set sample_type to "human" or "mouse".'
                    exit 1
                    ;;

                *)
                    echo "ERROR: Unsupported sample_type: ${SAMPLE_TYPE}"
                    echo 'Expected "human" or "mouse".'
                    exit 1
                    ;;
            esac
        fi

        echo "Sample ID: ${SAMPLE_ID}"
        echo "RNA FASTQ source: ${RNA_FASTQ_SOURCE}"
        echo "Protein FASTQ source: ${PROTEIN_FASTQ_SOURCE:-<none>}"
        echo "Transcriptome source: ${TRANSCRIPTOME_SOURCE}"
        echo "Probe-set source: ${PROBE_SET_SOURCE}"

        # ------------------------------------------------------------
        # Validate GCS inputs
        # ------------------------------------------------------------

        if [[ "${RNA_FASTQ_SOURCE}" != gs://* ]]; then
            echo "ERROR: rna_fastq_directory_path must start with gs://"
            echo "Received: ${RNA_FASTQ_SOURCE}"
            exit 2
        fi

        USE_PROTEIN=false

        if [[ -n "${PROTEIN_FASTQ_SOURCE}" ]]; then
            USE_PROTEIN=true

            if [[ "${PROTEIN_FASTQ_SOURCE}" != gs://* ]]; then
                echo "ERROR: protein_fastq_directory_path must start with gs://"
                echo "Received: ${PROTEIN_FASTQ_SOURCE}"
                exit 2
            fi

            if [[ -z "${FEATURE_REF_PATH}" ]]; then
                echo "ERROR: feature_reference_csv is required with protein_fastq_directory_path."
                exit 2
            fi

        elif [[ -n "${FEATURE_REF_PATH}" ]] || \
             [[ "${PROTEIN_SAMPLE_NAME}" != "None" ]]; then
            echo "ERROR: feature_reference_csv / protein_sample_name were supplied"
            echo "without protein_fastq_directory_path."
            exit 2
        fi

        if [[ "${TRANSCRIPTOME_SOURCE}" != gs://* ]]; then
            echo "ERROR: transcriptome_path must start with gs://"
            echo "Received: ${TRANSCRIPTOME_SOURCE}"
            exit 2
        fi

        if [[ "${PROBE_SET_SOURCE}" != gs://* ]]; then
            echo "ERROR: probe_set_path must start with gs://"
            echo "Received: ${PROBE_SET_SOURCE}"
            exit 2
        fi

        if [[ "${PROBE_SET_SOURCE}" != *.csv ]]; then
            echo "ERROR: probe_set_path must point to a CSV file."
            echo "Received: ${PROBE_SET_SOURCE}"
            exit 2
        fi

        # ------------------------------------------------------------
        # Copy FASTQs from GCS
        # ------------------------------------------------------------

        copy_fastqs() {
            local source="$1" dest="$2" label="$3"

            echo "Copying ${label} FASTQs from Google Cloud Storage..."
            mkdir -p "${dest}"

            gcloud storage rsync -r "${source%/}/" "${dest}/"

            if [[ -z "$(find "${dest}" -type f -print -quit)" ]]; then
                echo "ERROR: No ${label} FASTQ files were copied from:"
                echo "       ${source}"
                exit 3
            fi

            echo "${label} FASTQs copied to: ${dest}"
        }

        copy_fastqs "${RNA_FASTQ_SOURCE}" "${RNA_FASTQ_LOCAL_DIR}" "RNA"

        if [[ "${USE_PROTEIN}" == "true" ]]; then
            copy_fastqs "${PROTEIN_FASTQ_SOURCE}" "${PROTEIN_FASTQ_LOCAL_DIR}" "protein"
        fi

        # ------------------------------------------------------------
        # Resolve sample names against the actual FASTQ filenames
        # ------------------------------------------------------------

        # list_sample_prefixes <fastq dir>
        #
        # Prints each distinct FASTQ sample prefix (everything before
        # _S<n>_L<nnn>_R<n>_001.fastq.gz), one per line.
        list_sample_prefixes() {
            find "$1" -type f -name '*.fastq.gz' -exec basename {} \; |
                grep -E '_S[0-9]+_L[0-9]+_[RI][0-9]_[0-9]+\.fastq\.gz$' |
                sed -E 's/_S[0-9]+_L[0-9]+_[RI][0-9]_[0-9]+\.fastq\.gz$//' |
                sort -u || true
        }

        # resolve_sample_name <requested name or "None"> <fastq dir> <label>
        #
        # Space Ranger needs the exact FASTQ sample prefix. The requested name
        # may be a partial string of it; an exact match wins, otherwise it
        # must match exactly one prefix. When no name is requested ("None"),
        # the directory must contain exactly one sample, which is used.
        # Prints the resolved prefix on stdout; returns 1 when it cannot be
        # resolved unambiguously.
        resolve_sample_name() {
            local requested="$1" dir="$2" label="$3"
            local -a prefixes matches
            local prefix

            mapfile -t prefixes < <(list_sample_prefixes "${dir}")

            if [[ "${#prefixes[@]}" -eq 0 ]]; then
                echo "ERROR: no FASTQ files with 10x-style names found in the ${label} directory." >&2
                return 1
            fi

            if [[ "${requested}" == "None" ]]; then
                if [[ "${#prefixes[@]}" -eq 1 ]]; then
                    echo "${label} sample name not provided; detected '${prefixes[0]}'." >&2
                    echo "${prefixes[0]}"
                    return 0
                fi

                echo "ERROR: ${label} sample name not provided and the directory contains more than one sample." >&2
                echo "Available ${label} samples:" >&2
                printf '  %s\n' "${prefixes[@]}" >&2
                return 1
            fi

            for prefix in "${prefixes[@]}"; do
                if [[ "${prefix}" == "${requested}" ]]; then
                    echo "${label} sample name '${requested}' matches exactly." >&2
                    echo "${requested}"
                    return 0
                fi
            done

            matches=()
            for prefix in "${prefixes[@]}"; do
                if [[ "${prefix}" == *"${requested}"* ]]; then
                    matches+=("${prefix}")
                fi
            done

            if [[ "${#matches[@]}" -eq 1 ]]; then
                echo "${label} sample name '${requested}' resolved to '${matches[0]}'." >&2
                echo "${matches[0]}"
                return 0
            fi

            if [[ "${#matches[@]}" -eq 0 ]]; then
                echo "ERROR: ${label} sample name '${requested}' did not match any FASTQ sample." >&2
            else
                echo "ERROR: ${label} sample name '${requested}' matched more than one FASTQ sample." >&2
            fi
            echo "Available ${label} samples:" >&2
            printf '  %s\n' "${prefixes[@]}" >&2
            return 1
        }

        if [[ "${USE_PROTEIN}" == "true" ]]; then
            # The libraries CSV needs an explicit sample for each library.
            RNA_SAMPLE_NAME="$(resolve_sample_name "${RNA_SAMPLE_NAME}" "${RNA_FASTQ_LOCAL_DIR}" "RNA")"
            PROTEIN_SAMPLE_NAME="$(resolve_sample_name "${PROTEIN_SAMPLE_NAME}" "${PROTEIN_FASTQ_LOCAL_DIR}" "protein")"
        elif [[ "${RNA_SAMPLE_NAME}" != "None" ]]; then
            RNA_SAMPLE_NAME="$(resolve_sample_name "${RNA_SAMPLE_NAME}" "${RNA_FASTQ_LOCAL_DIR}" "RNA")"
        fi
        # RNA-only with no sample name: --sample is omitted and Space Ranger
        # uses every FASTQ in the directory, as before.

        # ------------------------------------------------------------
        # Copy or extract the transcriptome reference
        # ------------------------------------------------------------

        if [[ "${TRANSCRIPTOME_SOURCE%/}" == *.tar.gz ]]; then
            echo "Detected a compressed transcriptome reference."

            TRANSCRIPTOME_ARCHIVE="${INPUT_STAGING_DIR}/$(basename "${TRANSCRIPTOME_SOURCE}")"

            gcloud storage cp \
                "${TRANSCRIPTOME_SOURCE}" \
                "${TRANSCRIPTOME_ARCHIVE}"

            if [[ ! -s "${TRANSCRIPTOME_ARCHIVE}" ]]; then
                echo "ERROR: Transcriptome archive was not copied successfully:"
                echo "       ${TRANSCRIPTOME_SOURCE}"
                exit 4
            fi

            echo "Extracting transcriptome archive..."

            tar -xzf \
                "${TRANSCRIPTOME_ARCHIVE}" \
                -C "${TRANSCRIPTOME_STAGING_DIR}"
        else
            echo "Detected an uncompressed transcriptome directory."

            gcloud storage rsync -r \
                "${TRANSCRIPTOME_SOURCE%/}/" \
                "${TRANSCRIPTOME_STAGING_DIR}/"
        fi

        if [[ -z "$(find "${TRANSCRIPTOME_STAGING_DIR}" -type f -print -quit)" ]]; then
            echo "ERROR: No transcriptome files were copied or extracted from:"
            echo "       ${TRANSCRIPTOME_SOURCE}"
            exit 5
        fi

        # ------------------------------------------------------------
        # Find the transcriptome reference root
        # ------------------------------------------------------------

        mapfile -t REFERENCE_JSON_FILES < <(
            find "${TRANSCRIPTOME_STAGING_DIR}" \
                -type f \
                -name "reference.json" \
                -print
        )

        if [[ "${#REFERENCE_JSON_FILES[@]}" -eq 0 ]]; then
            echo "ERROR: No reference.json file was found under:"
            echo "       ${TRANSCRIPTOME_STAGING_DIR}"
            echo
            echo "The supplied transcriptome does not appear to be a valid"
            echo "10x Genomics transcriptome reference."
            exit 6
        fi

        if [[ "${#REFERENCE_JSON_FILES[@]}" -gt 1 ]]; then
            echo "ERROR: Multiple transcriptome references were found:"
            printf '  %s\n' "${REFERENCE_JSON_FILES[@]}"
            echo
            echo "Provide a GCS directory or archive containing one reference."
            exit 7
        fi

        TRANSCRIPTOME_LOCAL_DIR="$(dirname "${REFERENCE_JSON_FILES[0]}")"

        echo "Transcriptome reference directory:"
        echo "${TRANSCRIPTOME_LOCAL_DIR}"

        # ------------------------------------------------------------
        # Copy the probe-set CSV from GCS
        # ------------------------------------------------------------

        PROBE_SET_LOCAL_PATH="${INPUT_STAGING_DIR}/$(basename "${PROBE_SET_SOURCE}")"

        echo "Copying the probe-set CSV from Google Cloud Storage..."

        gcloud storage cp \
            "${PROBE_SET_SOURCE}" \
            "${PROBE_SET_LOCAL_PATH}"

        if [[ ! -s "${PROBE_SET_LOCAL_PATH}" ]]; then
            echo "ERROR: Probe-set file was not copied successfully:"
            echo "       ${PROBE_SET_SOURCE}"
            exit 8
        fi

        echo "Probe-set copied to:"
        echo "${PROBE_SET_LOCAL_PATH}"

        # ------------------------------------------------------------
        # Build the Space Ranger arguments
        # ------------------------------------------------------------

        count_args=(
            --id "${SAMPLE_ID}"
            --cytaimage "~{cytassist_image_path}"
            --create-bam "${BAM_FILE_SAVE}"
            --transcriptome "${TRANSCRIPTOME_LOCAL_DIR}"
            --probe-set "${PROBE_SET_LOCAL_PATH}"
            --custom-bin-size "${CUSTOM_BIN_SIZE}"
            --nucleus-segmentation "${NUCLEUS_SEGMENTATION}"
        )

        # Space Ranger only accepts protein (Antibody Capture) FASTQs through a
        # --libraries CSV; --fastqs/--sample are always treated as Gene
        # Expression. Build the CSV from the RNA and protein inputs.
        if [[ "${USE_PROTEIN}" == "true" ]]; then
            LIBRARIES_CSV="${INPUT_STAGING_DIR}/libraries.csv"

            {
                echo "fastqs,sample,library_type"
                echo "${RNA_FASTQ_LOCAL_DIR},${RNA_SAMPLE_NAME},Gene Expression"
                echo "${PROTEIN_FASTQ_LOCAL_DIR},${PROTEIN_SAMPLE_NAME},Antibody Capture"
            } > "${LIBRARIES_CSV}"

            echo "libraries.csv:"
            cat "${LIBRARIES_CSV}"

            count_args+=(
                --libraries "${LIBRARIES_CSV}"
                --feature-ref "${FEATURE_REF_PATH}"
            )
        else
            count_args+=(
                --fastqs "${RNA_FASTQ_LOCAL_DIR}"
            )

            if [[ "${RNA_SAMPLE_NAME}" != "None" ]]; then
                count_args+=(
                    --sample "${RNA_SAMPLE_NAME}"
                )
            fi
        fi

        if [[ -n "${HE_IMAGE_PATH}" ]]; then
            count_args+=(
                --image "${HE_IMAGE_PATH}"
            )
        fi

        if [[ -n "${REGISTRATION_JSON_PATH}" ]]; then
            count_args+=(
                --loupe-alignment "${REGISTRATION_JSON_PATH}"
            )
        fi

        echo
        echo "Running Space Ranger:"
        printf '  %q' spaceranger count "${count_args[@]}"
        echo
        echo

        spaceranger count "${count_args[@]}"

        # ------------------------------------------------------------
        # Post-processing
        # ------------------------------------------------------------

        SAMPLE_DIR="${WORK_ROOT}/${SAMPLE_ID}"
        OUTS_DIR="${SAMPLE_DIR}/outs"

        if [[ ! -d "${OUTS_DIR}" ]]; then
            echo "ERROR: Space Ranger output directory was not created:"
            echo "       ${OUTS_DIR}"
            exit 9
        fi

        echo "Space Ranger outs/ contents:"
        ls -la "${OUTS_DIR}"

        ADDITIONAL_DIR="${WORK_ROOT}/additional_outputs"
        mkdir -p "${ADDITIONAL_DIR}"

        # collect <required|optional> <source> <destination>
        #
        # Moves a file out of outs/. Symlinks (e.g. cloupe_cell.cloupe) are
        # dereferenced by copying, so they survive the later removal of the
        # directories they point into. Missing optional files only warn.
        collect() {
            local mode="$1" src="$2" dest="$3"

            if [[ ! -e "${src}" ]]; then
                if [[ "${mode}" == "required" ]]; then
                    echo "ERROR: expected output not found: ${src}"
                    exit 10
                fi
                echo "WARNING: optional output not found, skipping: ${src}"
                return 0
            fi

            if [[ -L "${src}" ]]; then
                cp -L "${src}" "${dest}"
            else
                mv "${src}" "${dest}"
            fi
        }

        # tar_dir <directory name under outs/>
        # Skipped when the directory is absent (e.g. segmentation disabled).
        tar_dir() {
            local name="$1"

            if [[ -d "${OUTS_DIR}/${name}" ]]; then
                tar -czvf \
                    "${OUTS_DIR}/${name}.tar.gz" \
                    -C "${OUTS_DIR}" \
                    "${name}"
            else
                echo "WARNING: ${name}/ not found in outs/, skipping archive."
            fi
        }

        tar_dir binned_outputs
        tar_dir spatial
        tar_dir segmented_outputs

        # Cloupe files must be collected before their parent directories
        # are deleted.
        CUSTOM_BIN_PADDED="$(printf "%03d" "${CUSTOM_BIN_SIZE}")"

        if [[ -e "${OUTS_DIR}/binned_outputs/square_008um/cloupe.cloupe" ]]; then
            collect optional \
                "${OUTS_DIR}/binned_outputs/square_008um/cloupe.cloupe" \
                "${SAMPLE_DIR}/cloupe_008um.cloupe"
        else
            collect optional \
                "${OUTS_DIR}/cloupe_008um.cloupe" \
                "${SAMPLE_DIR}/cloupe_008um.cloupe"
        fi

        if [[ "${CUSTOM_BIN_SIZE}" -ne 8 ]]; then
            if [[ -e "${OUTS_DIR}/binned_outputs/square_${CUSTOM_BIN_PADDED}um/cloupe.cloupe" ]]; then
                collect optional \
                    "${OUTS_DIR}/binned_outputs/square_${CUSTOM_BIN_PADDED}um/cloupe.cloupe" \
                    "${SAMPLE_DIR}/cloupe_${CUSTOM_BIN_SIZE}um.cloupe"
            else
                collect optional \
                    "${OUTS_DIR}/cloupe_custom.cloupe" \
                    "${SAMPLE_DIR}/cloupe_${CUSTOM_BIN_SIZE}um.cloupe"
            fi
        fi

        collect optional \
            "${OUTS_DIR}/cloupe_cell.cloupe" \
            "${SAMPLE_DIR}/cloupe_cell.cloupe"

        # Drop the top-level cloupe symlinks and the directories they pointed
        # into; their contents are already collected or archived above.
        rm -f \
            "${OUTS_DIR}/cloupe_008um.cloupe" \
            "${OUTS_DIR}/cloupe_custom.cloupe" \
            "${OUTS_DIR}/cloupe_cell.cloupe"

        rm -rf "${OUTS_DIR}/binned_outputs"
        rm -rf "${OUTS_DIR}/spatial"
        rm -rf "${OUTS_DIR}/segmented_outputs"

        if [[ "${BAM_FILE_SAVE}" == "true" ]]; then
            collect required \
                "${OUTS_DIR}/possorted_genome_bam.bam" \
                "${SAMPLE_DIR}/possorted_genome_bam.bam"

            # Genomes with very long chromosomes get a .csi index instead of
            # .bai; the .csi is picked up by the additional outputs sweep.
            collect optional \
                "${OUTS_DIR}/possorted_genome_bam.bam.bai" \
                "${SAMPLE_DIR}/possorted_genome_bam.bam.bai"
        fi

        collect required \
            "${OUTS_DIR}/metrics_summary.csv" \
            "${SAMPLE_DIR}/metrics_summary.csv"

        collect required \
            "${OUTS_DIR}/web_summary.html" \
            "${SAMPLE_DIR}/web_summary.html"

        collect required \
            "${OUTS_DIR}/molecule_info.h5" \
            "${SAMPLE_DIR}/molecule_info.h5"

        collect required \
            "${OUTS_DIR}/feature_slice.h5" \
            "${SAMPLE_DIR}/feature_slice.h5"

        collect required \
            "${OUTS_DIR}/binned_outputs.tar.gz" \
            "${SAMPLE_DIR}/binned_outputs.tar.gz"

        collect required \
            "${OUTS_DIR}/spatial.tar.gz" \
            "${SAMPLE_DIR}/spatial.tar.gz"

        collect optional \
            "${OUTS_DIR}/probe_set.csv" \
            "${SAMPLE_DIR}/probe_set.csv"

        collect optional \
            "${OUTS_DIR}/segmented_outputs.tar.gz" \
            "${SAMPLE_DIR}/segmented_outputs.tar.gz"

        collect optional \
            "${OUTS_DIR}/barcode_mappings.parquet" \
            "${SAMPLE_DIR}/barcode_mappings.parquet"

        # ------------------------------------------------------------
        # Sweep up anything else Space Ranger produced (e.g. protein
        # outputs such as feature_reference.csv, filtered/raw matrices,
        # analysis/). Directories are archived, symlinks are resolved.
        # ------------------------------------------------------------

        shopt -s nullglob dotglob

        for entry in "${OUTS_DIR}"/*; do
            name="$(basename "${entry}")"

            if [[ -d "${entry}" ]]; then
                echo "Archiving additional directory: ${name}/"
                tar -czhf "${ADDITIONAL_DIR}/${name}.tar.gz" -C "${OUTS_DIR}" "${name}"
            elif [[ -L "${entry}" ]]; then
                echo "Copying additional symlinked file: ${name}"
                cp -L "${entry}" "${ADDITIONAL_DIR}/${name}"
            else
                echo "Moving additional file: ${name}"
                mv "${entry}" "${ADDITIONAL_DIR}/${name}"
            fi
        done

        shopt -u nullglob dotglob

        echo "Additional outputs:"
        ls -la "${ADDITIONAL_DIR}"

        # Bundle the extras into a single archive next to the main outputs.
        if [[ -n "$(find "${ADDITIONAL_DIR}" -mindepth 1 -print -quit)" ]]; then
            tar -czvf \
                "${SAMPLE_DIR}/additional_outputs.tar.gz" \
                -C "${ADDITIONAL_DIR}" \
                .
        else
            echo "No additional outputs to archive."
        fi

        rm -rf "${OUTS_DIR}"
    >>>

    output {
        Array[File?] space_ranger_outputs = [
            "./~{sample_id}/binned_outputs.tar.gz",
            "./~{sample_id}/spatial.tar.gz",
            "./~{sample_id}/cloupe_008um.cloupe",
            "./~{sample_id}/cloupe_~{custom_bin_size}um.cloupe",
            "./~{sample_id}/feature_slice.h5",
            "./~{sample_id}/molecule_info.h5",
            "./~{sample_id}/metrics_summary.csv",
            "./~{sample_id}/probe_set.csv",
            "./~{sample_id}/possorted_genome_bam.bam",
            "./~{sample_id}/possorted_genome_bam.bam.bai",
            "./~{sample_id}/web_summary.html",
            "./~{sample_id}/segmented_outputs.tar.gz",
            "./~{sample_id}/cloupe_cell.cloupe",
            "./~{sample_id}/barcode_mappings.parquet",
            "./~{sample_id}/additional_outputs.tar.gz"
        ]
    }

    runtime {
        docker: "jishar7/space_ranger:V4.0"
        memory: memory + " GiB"
        cpu: cpu
        preemptible: preemptible_attempts
        disks: "local-disk " + disk_size + if use_ssd then " SSD" else " HDD"
    }
}