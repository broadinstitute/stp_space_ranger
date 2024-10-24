version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    input {

        Array[File] cytassist_image_path
        Array[File] he_image_path
        Array[File]? registration_json_file_path
        Array[File] fastq_file_path
        Array[String] bam_file_save
        Array[File] transcriptome_file_path
        Array[File] probe_set_file_path
        Float amount_of_VMs
        Array[String] prefix_list_of_fastqs

    }

    Int num_files_per_vm = ceil(length(cytassist_image_path) / amount_of_VMs)

    scatter (i in range(amount_of_VMs)) {

        String index_of_vm = "~{i}"

        Array[File] sliced_cytassist_image_path = cytassist_image_path[i*num_files_per_vm : (i+1)*num_files_per_vm]
        Array[File] sliced_he_image_path = he_image_path[i*num_files_per_vm : (i+1)*num_files_per_vm]
        Array[File]? sliced_registration_json_file_path = registration_json_file_path[i*num_files_per_vm : (i+1)*num_files_per_vm]
        Array[File] sliced_probe_set_file_path = probe_set_file_path[i*num_files_per_vm : (i+1)*num_files_per_vm]
        Array[File] sliced_fastq_file_dir = fastq_file_path[i*(num_files_per_vm*2) : (i+1)*(num_files_per_vm*2)]
        Array[String] sliced_bam_file_save = bam_file_save[i*num_files_per_vm : (i+1)*num_files_per_vm]
        Array[String] sliced_prefix_list_of_fastqs = prefix_list_of_fastqs[i*num_files_per_vm : (i+1)*num_files_per_vm]

        call SPACE_RANGER.space_ranger as space_ranger {
            input:
                cytassist_image_path = sliced_cytassist_image_path,
                he_image_path = sliced_he_image_path,
                registration_json_file_path = sliced_registration_json_file_path,
                fastq_file_dir = sliced_fastq_file_dir,
                bam_file_save = sliced_bam_file_save,
                transcriptome_file_path = transcriptome_file_path,
                probe_set_file_path = sliced_probe_set_file_path,
                prefix_list_of_fastqs = sliced_prefix_list_of_fastqs,
                index_of_vm = index_of_vm
        }
    }
}
