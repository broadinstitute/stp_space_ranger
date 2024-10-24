version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    input {
        File cytassist_image_path
        File he_image_path
        File fastq_read1_file_path
        File fastq_read2_file_path
        File transcriptome_file_path
        File probe_set_file_path
        String sample_id
        String bam_file_save  # "true" or "false"
    }

    call SPACE_RANGER.space_ranger {
        input:
            cytassist_image_path = cytassist_image_path,
            he_image_path = he_image_path,
            fastq_read1_file_path = fastq_read1_file_path,
            fastq_read2_file_path = fastq_read2_file_path,
            bam_file_save = bam_file_save,
            transcriptome_file_path = transcriptome_file_path,
            probe_set_file_path = probe_set_file_path,
            sample_id = sample_id
    }
}