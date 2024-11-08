version 1.0
task space_ranger {

    input {       
        File cytassist_image_path
        File fastq_read1_file_path
        File fastq_read2_file_path
        File? transcriptome_file_path
        File? probe_set_file_path
        String sample_id
        String bam_file_save  # "true" or "false"
    }

    command <<<

        gcloud storage cp -r "gs://fc-d8650e80-227f-42d3-aacb-083f9da586cc/data/2024-09-10/space_ranger_dummy_files" "/cromwell_root/"

        cd space_ranger_dummy_files
        cat dummy_text_file.txt
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
        docker: "jishar7/space_ranger@sha256:7a8cda3d8746e78666c3ef91c919f3ad94ff9bec11a495e8e9df0034b8cc5b6a"
        memory: "130GB"
        cpu: 10
        preemptible: 2
        disks: "local-disk 1000 HDD"
    }

}