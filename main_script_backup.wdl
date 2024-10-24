version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    input {

        Array[File] cytassist_image_path
        Array[File] he_image_path
        Array[File] fastq_file_path
        Array[String] bam_file_save  # "true" or "false"
        Array[File] transcriptome_file_path
        Array[File] probe_set_file_path
        Int amount_of_VMs
        Array[String] prefix_list_of_fastqs
    }

    Int num_files_per_vm = ceil(length(cytassist_image_path) / amount_of_VMs)

    scatter (i in range(amount_of_VMs)) {
        call SPACE_RANGER.space_ranger {
            input:
                cytassist_image_path = cytassist_image_path,
                he_image_path = he_image_path,
                fastq_file_path = fastq_file_path,
                bam_file_save = bam_file_save,
                transcriptome_file_path = transcriptome_file_path,
                probe_set_file_path = probe_set_file_path,
                prefix_list_of_fastqs = prefix_list_of_fastqs,
                index_of_vm = i,
                num_files_per_vm = num_files_per_vm
        }
    }
}