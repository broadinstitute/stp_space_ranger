version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    input {
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file
        File fastq_read1_file_path
        File fastq_read2_file_path
        String sample_type # human or mouse
        String sample_id
        String bam_file_save  # "true" or "false"
    }

    File dummy_he_image_path = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_dummy_files/dummy_he.tif"
    File dummy_registration_json_file = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_dummy_files/dummy_json_file.json"

    File? transcriptome_file_path = "None"
    File? probe_set_file_path = "None"

    if (sample_type == "mouse") {
        transcriptome_file_path = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_references/mouse/refdata-gex-mm10-2020-A.tar.gz"
        probe_set_file_path = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_probe_sets/mouse/Visium_Mouse_Transcriptome_Probe_Set_v2.0_mm10-2020-A.csv"
    } 
    
    if (sample_type == "human") {
        transcriptome_file_path = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_references/human/refdata-gex-GRCh38-2020-A.tar.gz"
        probe_set_file_path = "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_probe_sets/human/Visium_Human_Transcriptome_Probe_Set_v2.0_GRCh38-2020-A.csv"
    }

    call SPACE_RANGER.space_ranger {

        input:
            cytassist_image_path = cytassist_image_path,
            he_image_path = if defined(he_image_path) then select_first([he_image_path]) else dummy_he_image_path,
            registration_json_file = if defined(registration_json_file) then select_first([registration_json_file]) else dummy_registration_json_file,
            fastq_read1_file_path = fastq_read1_file_path,
            fastq_read2_file_path = fastq_read2_file_path,
            transcriptome_file_path = transcriptome_file_path,
            probe_set_file_path = probe_set_file_path,
            sample_id = sample_id,
            bam_file_save = bam_file_save,
            dummy_he_image_path = dummy_he_image_path,
            dummy_registration_json_file = dummy_registration_json_file
    }
}