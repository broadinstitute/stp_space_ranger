version 1.0
task space_ranger {

    input {       
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file
        File fastq_read1_file_path
        File fastq_read2_file_path
        File? transcriptome_file_path
        File? probe_set_file_path
        String sample_id
        String bam_file_save  # "true" or "false"
        File dummy_he_image_path
        File dummy_registration_json_file
    }

    command <<<

        gsutil cp -r "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_dummy_files" "/cromwell_root/"

        cd space_ranger_dummy_files
        cat hello_there.txt

    >>>

    output {
        Array[File?] space_ranger_outputs = [
            "./~{sample_id}/binned_outputs.tar.gz",
            "./~{sample_id}/spatial.tar.gz",
            "./~{sample_id}/cloupe_008um.cloupe",
            "./~{sample_id}/feature_slice.h5",
            "./~{sample_id}/molecule_info.h5",
            "./~{sample_id}/metrics_summary.csv",
            "./~{sample_id}/probe_set.csv",
            "./~{sample_id}/possorted_genome_bam.bam",
            "./~{sample_id}/possorted_genome_bam.bam.bai",
            "./~{sample_id}/web_summary.html"
        ]
    }

    runtime {
        docker: "jishar7/space_ranger@sha256:9318bf14d4801f7756578628aeef8a89008c6fd2667b2bb272f537570f6f3e3f"
        memory: "130GB"
        cpu: 10
        preemptible: 2
        disks: "local-disk 1000 HDD"
    }

}