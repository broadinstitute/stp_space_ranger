version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    input {
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file

        String fastq_reads_directory_path
        String? sample_name

        # Optional when both custom reference paths are supplied.
        #
        # Required when using the default references.
        # Supported values:
        #   human
        #   mouse
        String? sample_type

        String sample_id

        Boolean bam_file_save = false

        Int? disk_size
        Int? cpu
        Boolean use_ssd = false
        Int? memory
        Int? preemptible_attempts
        Int? custom_bin_size

        Boolean nucleus_segmentation = true

        # Optional custom GCS transcriptome path.
        #
        # Supported formats:
        #   gs://bucket/reference.tar.gz
        #   gs://bucket/uncompressed-reference-directory/
        #
        # transcriptome_path and probe_set_path must either both be
        # supplied or both be omitted.
        String? transcriptome_path

        # Optional custom GCS probe-set CSV path.
        #
        # Example:
        #   gs://bucket/custom_probe_set.csv
        #
        # transcriptome_path and probe_set_path must either both be
        # supplied or both be omitted.
        String? probe_set_path
    }

    call SPACE_RANGER.space_ranger {

        input:
            cytassist_image_path = cytassist_image_path,
            he_image_path = he_image_path,
            registration_json_file = registration_json_file,

            fastq_reads_directory_path = fastq_reads_directory_path,

            sample_type = if defined(sample_type) then
                select_first([sample_type])
            else
                "",

            transcriptome_path = if defined(transcriptome_path) then
                select_first([transcriptome_path])
            else
                "",

            probe_set_path = if defined(probe_set_path) then
                select_first([probe_set_path])
            else
                "",

            sample_id = sample_id,

            sample_name = if defined(sample_name) then
                select_first([sample_name])
            else
                "None",

            bam_file_save = bam_file_save,

            disk_size = if defined(disk_size) then
                select_first([disk_size])
            else
                1000,

            cpu = if defined(cpu) then
                select_first([cpu])
            else
                32,

            use_ssd = use_ssd,

            memory = if defined(memory) then
                select_first([memory])
            else
                128,

            preemptible_attempts = if defined(preemptible_attempts) then
                select_first([preemptible_attempts])
            else
                1,

            custom_bin_size = if defined(custom_bin_size) then
                select_first([custom_bin_size])
            else
                8,

            nucleus_segmentation = nucleus_segmentation
    }

    output {
        Array[File?] space_ranger_outputs =
            space_ranger.space_ranger_outputs
    }
}