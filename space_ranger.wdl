version 1.0

task space_ranger {

    input {
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file

        String fastq_reads_directory_path
        String sample_name

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
        SAMPLE_NAME="~{sample_name}"
        SAMPLE_TYPE="~{sample_type}"

        FASTQ_SOURCE="~{fastq_reads_directory_path}"
        TRANSCRIPTOME_SOURCE="~{transcriptome_path}"
        PROBE_SET_SOURCE="~{probe_set_path}"

        HE_IMAGE_PATH="~{if defined(he_image_path) then select_first([he_image_path]) else ""}"
        REGISTRATION_JSON_PATH="~{if defined(registration_json_file) then select_first([registration_json_file]) else ""}"

        BAM_FILE_SAVE="~{bam_file_save}"
        NUCLEUS_SEGMENTATION="~{nucleus_segmentation}"
        CUSTOM_BIN_SIZE="~{custom_bin_size}"

        WORK_ROOT="${PWD}"

        FASTQ_LOCAL_DIR="${WORK_ROOT}/fastqs"
        TRANSCRIPTOME_STAGING_DIR="${WORK_ROOT}/transcriptome"
        INPUT_STAGING_DIR="${WORK_ROOT}/input_files"

        mkdir -p \
            "${FASTQ_LOCAL_DIR}" \
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
        echo "FASTQ source: ${FASTQ_SOURCE}"
        echo "Transcriptome source: ${TRANSCRIPTOME_SOURCE}"
        echo "Probe-set source: ${PROBE_SET_SOURCE}"

        # ------------------------------------------------------------
        # Validate GCS inputs
        # ------------------------------------------------------------

        if [[ "${FASTQ_SOURCE}" != gs://* ]]; then
            echo "ERROR: fastq_reads_directory_path must start with gs://"
            echo "Received: ${FASTQ_SOURCE}"
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

        echo "Copying FASTQs from Google Cloud Storage..."

        gcloud storage rsync -r \
            "${FASTQ_SOURCE%/}/" \
            "${FASTQ_LOCAL_DIR}/"

        if [[ -z "$(find "${FASTQ_LOCAL_DIR}" -type f -print -quit)" ]]; then
            echo "ERROR: No FASTQ files were copied from:"
            echo "       ${FASTQ_SOURCE}"
            exit 3
        fi

        echo "FASTQs copied to:"
        echo "${FASTQ_LOCAL_DIR}"

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
            --fastqs "${FASTQ_LOCAL_DIR}"
            --cytaimage "~{cytassist_image_path}"
            --create-bam "${BAM_FILE_SAVE}"
            --transcriptome "${TRANSCRIPTOME_LOCAL_DIR}"
            --probe-set "${PROBE_SET_LOCAL_PATH}"
            --custom-bin-size "${CUSTOM_BIN_SIZE}"
            --nucleus-segmentation "${NUCLEUS_SEGMENTATION}"
        )

        if [[ "${SAMPLE_NAME}" != "None" ]]; then
            count_args+=(
                --sample "${SAMPLE_NAME}"
            )
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

        tar -czvf \
            "${OUTS_DIR}/binned_outputs.tar.gz" \
            -C "${OUTS_DIR}" \
            binned_outputs

        tar -czvf \
            "${OUTS_DIR}/spatial.tar.gz" \
            -C "${OUTS_DIR}" \
            spatial

        tar -czvf \
            "${OUTS_DIR}/segmented_outputs.tar.gz" \
            -C "${OUTS_DIR}" \
            segmented_outputs

        CUSTOM_BIN_PADDED="$(printf "%03d" "${CUSTOM_BIN_SIZE}")"

        mv \
            "${OUTS_DIR}/binned_outputs/square_008um/cloupe.cloupe" \
            "${SAMPLE_DIR}/cloupe_008um.cloupe"

        if [[ "${CUSTOM_BIN_SIZE}" -ne 8 ]]; then
            mv \
                "${OUTS_DIR}/binned_outputs/square_${CUSTOM_BIN_PADDED}um/cloupe.cloupe" \
                "${SAMPLE_DIR}/cloupe_${CUSTOM_BIN_SIZE}um.cloupe"
        fi

        rm -rf "${OUTS_DIR}/binned_outputs"
        rm -rf "${OUTS_DIR}/spatial"
        rm -rf "${OUTS_DIR}/segmented_outputs"

        if [[ "${BAM_FILE_SAVE}" == "true" ]]; then
            mv \
                "${OUTS_DIR}/possorted_genome_bam.bam" \
                "${SAMPLE_DIR}/possorted_genome_bam.bam"

            mv \
                "${OUTS_DIR}/possorted_genome_bam.bam.bai" \
                "${SAMPLE_DIR}/possorted_genome_bam.bam.bai"
        fi

        mv \
            "${OUTS_DIR}/probe_set.csv" \
            "${SAMPLE_DIR}/probe_set.csv"

        mv \
            "${OUTS_DIR}/binned_outputs.tar.gz" \
            "${SAMPLE_DIR}/binned_outputs.tar.gz"

        mv \
            "${OUTS_DIR}/feature_slice.h5" \
            "${SAMPLE_DIR}/feature_slice.h5"

        mv \
            "${OUTS_DIR}/metrics_summary.csv" \
            "${SAMPLE_DIR}/metrics_summary.csv"

        mv \
            "${OUTS_DIR}/molecule_info.h5" \
            "${SAMPLE_DIR}/molecule_info.h5"

        mv \
            "${OUTS_DIR}/spatial.tar.gz" \
            "${SAMPLE_DIR}/spatial.tar.gz"

        mv \
            "${OUTS_DIR}/web_summary.html" \
            "${SAMPLE_DIR}/web_summary.html"

        mv \
            "${OUTS_DIR}/segmented_outputs.tar.gz" \
            "${SAMPLE_DIR}/segmented_outputs.tar.gz"

        mv \
            "${OUTS_DIR}/cloupe_cell.cloupe" \
            "${SAMPLE_DIR}/cloupe_cell.cloupe"

        mv \
            "${OUTS_DIR}/barcode_mappings.parquet" \
            "${SAMPLE_DIR}/barcode_mappings.parquet"

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
            "./~{sample_id}/barcode_mappings.parquet"
        ]
    }

    runtime {
        docker: "jishar7/space_ranger:V2.0"
        memory: memory + " GiB"
        cpu: cpu
        preemptible: preemptible_attempts
        disks: "local-disk " + disk_size + if use_ssd then " SSD" else " HDD"
    }
}