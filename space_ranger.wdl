version 1.0
task space_ranger {

    input {
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file
        String fastq_reads_directory_path
        String? sample_name
        File? transcriptome_file_path
        File? probe_set_file_path
        String sample_id
        Boolean bam_file_save
        File dummy_he_image_path
        File dummy_registration_json_file
        Int? disk_size
        Int? cpu
        Boolean use_ssd
        Int? memory
        Int? preemptible_attempts
        Int? custom_bin_size
        Boolean nucleus_segmentation
        Boolean use_probe_set
    }

    command <<<

        set -euo pipefail

        USER_DATA_DIR="~{fastq_reads_directory_path}"
        DATA_ROOT="${PWD}"

        echo "Checking data_dir source: ${USER_DATA_DIR}"

        if [[ "${USER_DATA_DIR}" == s3://* ]]; then
          aws s3 sync "${USER_DATA_DIR%/}" "${DATA_ROOT}/"

        elif [[ "${USER_DATA_DIR}" == gs://* ]]; then
          gcloud storage cp -r "${USER_DATA_DIR%/}" "${DATA_ROOT}/"

        else
          echo "ERROR: data_dir must start with s3:// or gs://"
          exit 1
        fi

        fastq_folder_name=$(basename ~{fastq_reads_directory_path})

        transcriptome_directory=$(dirname ~{transcriptome_file_path})
        tar -xzf ~{transcriptome_file_path} -C "$transcriptome_directory"
        unzipped_dir_name=$(basename ~{transcriptome_file_path} .tar.gz)
        unzipped_transcriptome_dir="$transcriptome_directory/$unzipped_dir_name/"

        echo "The fastq directory basename is: ${fastq_folder_name}"
        echo "The fastq directory is: ${DATA_ROOT}/$fastq_folder_name"

        # Build the spaceranger count args incrementally
        count_args=(
            --id ~{sample_id}
            --fastqs "${DATA_ROOT}/${fastq_folder_name}"
            --cytaimage ~{cytassist_image_path}
            --create-bam ~{bam_file_save}
            --transcriptome "${unzipped_transcriptome_dir}"
            --custom-bin-size ~{custom_bin_size}
            --nucleus-segmentation ~{nucleus_segmentation}
        )

        # Conditional: probe set (new toggle)
        if [[ ~{use_probe_set} == true ]]; then
            count_args+=( --probe-set ~{probe_set_file_path} )
        fi

        # Conditional: sample name
        if [[ ~{sample_name} != "None" ]]; then
            count_args+=( --sample ~{sample_name} )
        fi

        # Conditional: H&E image (skip if dummy)
        if [[ ~{he_image_path} != ~{dummy_he_image_path} ]]; then
            count_args+=( --image ~{he_image_path} )
        fi

        # Conditional: registration json (skip if dummy)
        if [[ ~{registration_json_file} != ~{dummy_registration_json_file} ]]; then
            count_args+=( --loupe-alignment ~{registration_json_file} )
        fi

        # Run spaceranger once with the assembled arguments
        spaceranger count "${count_args[@]}"

        # ---------- Post-processing (unchanged behavior) ----------
        tar -czvf "${DATA_ROOT}/~{sample_id}/outs/binned_outputs.tar.gz" -C "${DATA_ROOT}/~{sample_id}/outs" binned_outputs
        tar -czvf "${DATA_ROOT}/~{sample_id}/outs/spatial.tar.gz" -C "${DATA_ROOT}/~{sample_id}/outs" spatial
        tar -czvf "${DATA_ROOT}/~{sample_id}/outs/segmented_outputs.tar.gz" -C "${DATA_ROOT}/~{sample_id}/outs" segmented_outputs

        mv "${DATA_ROOT}/~{sample_id}/outs/binned_outputs/square_008um/cloupe.cloupe" "${DATA_ROOT}/~{sample_id}/cloupe_008um.cloupe"

        if [[ ~{custom_bin_size} -ne 8 ]]; then
            mv "${DATA_ROOT}/~{sample_id}/outs/binned_outputs/square_~{custom_bin_size}um/cloupe.cloupe" "${DATA_ROOT}/~{sample_id}/cloupe_~{custom_bin_size}um.cloupe"
        fi

        rm -rf "${DATA_ROOT}/~{sample_id}/outs/binned_outputs"
        rm -rf "${DATA_ROOT}/~{sample_id}/outs/spatial"
        rm -rf "${DATA_ROOT}/~{sample_id}/outs/segmented_outputs"

        if [[ ~{bam_file_save} == true ]]; then
            mv "${DATA_ROOT}/~{sample_id}/outs/possorted_genome_bam.bam" "${DATA_ROOT}/~{sample_id}/possorted_genome_bam.bam"
            mv "${DATA_ROOT}/~{sample_id}/outs/possorted_genome_bam.bam.bai" "${DATA_ROOT}/~{sample_id}/possorted_genome_bam.bam.bai"
        fi

        if [[ ~{use_probe_set} == true ]]; then
            mv "${DATA_ROOT}/~{sample_id}/outs/probe_set.csv" "${DATA_ROOT}/~{sample_id}/probe_set.csv"
        fi

        mv "${DATA_ROOT}/~{sample_id}/outs/binned_outputs.tar.gz" "${DATA_ROOT}/~{sample_id}/binned_outputs.tar.gz"
        mv "${DATA_ROOT}/~{sample_id}/outs/feature_slice.h5" "${DATA_ROOT}/~{sample_id}/feature_slice.h5"
        mv "${DATA_ROOT}/~{sample_id}/outs/metrics_summary.csv" "${DATA_ROOT}/~{sample_id}/metrics_summary.csv"
        mv "${DATA_ROOT}/~{sample_id}/outs/molecule_info.h5" "${DATA_ROOT}/~{sample_id}/molecule_info.h5"
        mv "${DATA_ROOT}/~{sample_id}/outs/spatial.tar.gz" "${DATA_ROOT}/~{sample_id}/spatial.tar.gz"
        mv "${DATA_ROOT}/~{sample_id}/outs/web_summary.html" "${DATA_ROOT}/~{sample_id}/web_summary.html"
        mv "${DATA_ROOT}/~{sample_id}/outs/segmented_outputs.tar.gz" "${DATA_ROOT}/~{sample_id}/segmented_outputs.tar.gz"
        mv "${DATA_ROOT}/~{sample_id}/outs/cloupe_cell.cloupe" "${DATA_ROOT}/~{sample_id}/cloupe_cell.cloupe"
        mv "${DATA_ROOT}/~{sample_id}/outs/barcode_mappings.parquet" "${DATA_ROOT}/~{sample_id}/barcode_mappings.parquet"

        rm -rf "${DATA_ROOT}/~{sample_id}/outs"

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
        docker: "jishar7/space_ranger@sha256:ad92e1cb5301de292ff0b7bc88ab5e807a14c819a455356588b548941800f492"
        memory: memory + " GiB"
        cpu: cpu
        preemptible: preemptible_attempts
        disks: "local-disk " + disk_size + if use_ssd then " SSD" else " HDD"
    }

}