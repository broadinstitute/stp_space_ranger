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
    
        fastq_files_directory=$(dirname ~{fastq_read1_file_path})

        transcriptome_directory=$(dirname ~{transcriptome_file_path})
        tar -xzf ~{transcriptome_file_path} -C "$transcriptome_directory"
        unzipped_dir_name=$(basename ~{transcriptome_file_path} .tar.gz)
        unzipped_transcriptome_dir="$transcriptome_directory/$unzipped_dir_name/"

        if [ ~{he_image_path} == ~{dummy_he_image_path} ]; then
            if [ ~{registration_json_file} == ~{dummy_registration_json_file} ]; then
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_files_directory" \
                        --cytaimage ~{cytassist_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path}
            else
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_files_directory" \
                        --cytaimage ~{cytassist_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path} \
                        --loupe-alignment ~{registration_json_file}
            fi

        else
            if [ ~{registration_json_file} == ~{dummy_registration_json_file} ]; then
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_files_directory" \
                        --cytaimage ~{cytassist_image_path} \
                        --image ~{he_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path}
            else
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_files_directory" \
                        --cytaimage ~{cytassist_image_path} \
                        --image ~{he_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path} \
                        --loupe-alignment ~{registration_json_file}
            fi
        fi

        tar -czvf "/cromwell_root/~{sample_id}/outs/binned_outputs.tar.gz" -C "/cromwell_root/~{sample_id}/outs" binned_outputs
        tar -czvf "/cromwell_root/~{sample_id}/outs/spatial.tar.gz" -C "/cromwell_root/~{sample_id}/outs" spatial

        mv "/cromwell_root/~{sample_id}/outs/binned_outputs/square_008um/cloupe.cloupe" "/cromwell_root/~{sample_id}/cloupe_008um.cloupe"

        rm -rf "/cromwell_root/~{sample_id}/outs/binned_outputs"
        rm -rf "/cromwell_root/~{sample_id}/outs/spatial"

        if [[ ~{bam_file_save} == "true" ]]; then
            mv "/cromwell_root/~{sample_id}/outs/possorted_genome_bam.bam" "/cromwell_root/~{sample_id}/possorted_genome_bam.bam"
            mv "/cromwell_root/~{sample_id}/outs/possorted_genome_bam.bam.bai" "/cromwell_root/~{sample_id}/possorted_genome_bam.bam.bai"
        fi
        
        mv "/cromwell_root/~{sample_id}/outs/binned_outputs.tar.gz" "/cromwell_root/~{sample_id}/binned_outputs.tar.gz"
        mv "/cromwell_root/~{sample_id}/outs/feature_slice.h5" "/cromwell_root/~{sample_id}/feature_slice.h5"
        mv "/cromwell_root/~{sample_id}/outs/metrics_summary.csv" "/cromwell_root/~{sample_id}/metrics_summary.csv"
        mv "/cromwell_root/~{sample_id}/outs/molecule_info.h5" "/cromwell_root/~{sample_id}/molecule_info.h5"
        mv "/cromwell_root/~{sample_id}/outs/probe_set.csv" "/cromwell_root/~{sample_id}/probe_set.csv"
        mv "/cromwell_root/~{sample_id}/outs/spatial.tar.gz" "/cromwell_root/~{sample_id}/spatial.tar.gz"
        mv "/cromwell_root/~{sample_id}/outs/web_summary.html" "/cromwell_root/~{sample_id}/web_summary.html"

        rm -rf "/cromwell_root/~{sample_id}/outs"

    >>>

    output {
        Array[File?] space_ranger_outputs = [
            "/cromwell_root/~{sample_id}/binned_outputs.tar.gz",
            "/cromwell_root/~{sample_id}/spatial.tar.gz",
            "/cromwell_root/~{sample_id}/cloupe_008um.cloupe"
            "/cromwell_root/~{sample_id}/feature_slice.h5",
            "/cromwell_root/~{sample_id}/molecule_info.h5",
            "/cromwell_root/~{sample_id}/metrics_summary.csv",
            "/cromwell_root/~{sample_id}/probe_set.csv",
            "/cromwell_root/~{sample_id}/possorted_genome_bam.bam",
            "/cromwell_root/~{sample_id}/possorted_genome_bam.bam.bai",
            "/cromwell_root/~{sample_id}/web_summary.html",
        ]
    }


    runtime {
        docker: "jishar7/space_ranger@sha256:538f88a9f9cfe997b0bf7480fea05a724267c1f13ce1c406e65e16bdcbc8db04"
        memory: "130GB"
        cpu: 10
        preemptible: 2
        disks: "local-disk 1000 HDD"
    }

}