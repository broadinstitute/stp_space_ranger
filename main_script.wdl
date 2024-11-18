version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    input {
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file
        String fastq_reads_directory_path
        String? sample_name
        String sample_type # human or mouse
        String sample_id
        String bam_file_save  # "true" or "false"
        Int? disk_size
        Int? cpu
        Boolean? use_ssd 
        Int? memory
        Int? preemptible_attempts
    }

    File dummy_he_image_path = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_dummy_files/dummy_he.tif"
    File dummy_registration_json_file = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_dummy_files/dummy_json_file.json"

    File? transcriptome_file_path = if sample_type == "mouse" then "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_references/mouse/refdata-gex-mm10-2020-A.tar.gz" else "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_references/human/refdata-gex-GRCh38-2020-A.tar.gz"
    File? probe_set_file_path = if sample_type == "mouse" then "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_probe_sets/mouse/Visium_Mouse_Transcriptome_Probe_Set_v2.0_mm10-2020-A.csv" else "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_probe_sets/human/Visium_Human_Transcriptome_Probe_Set_v2.0_GRCh38-2020-A.csv"

    call SPACE_RANGER.space_ranger {

        input:
            cytassist_image_path = cytassist_image_path,
            he_image_path = if defined(he_image_path) then select_first([he_image_path]) else dummy_he_image_path,
            registration_json_file = if defined(registration_json_file) then select_first([registration_json_file]) else dummy_registration_json_file,
            fastq_reads_directory_path = fastq_reads_directory_path,
            transcriptome_file_path = transcriptome_file_path,
            probe_set_file_path = probe_set_file_path,
            sample_id = sample_id,
            bam_file_save = bam_file_save,
            dummy_he_image_path = dummy_he_image_path,
            dummy_registration_json_file = dummy_registration_json_file,
            sample_name=if defined(sample_name) then select_first([sample_name]) else "None",
            disk_size=if defined(disk_size) then select_first([disk_size]) else 50,
            cpu=if defined(cpu) then select_first([cpu]) else 4,
            use_ssd=if defined(use_ssd) then select_first([use_ssd]) else "false",   
            memory=if defined(memory) then select_first([memory]) else 8,
            preemptible_attempts=if defined(preemptible_attempts) then select_first([preemptible_attempts]) else 0,
    }
}