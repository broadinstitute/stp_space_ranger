version 1.0
task space_ranger {

    input {       
        File cytassist_image_path
        File? he_image_path
        File? registration_json_file
        String fastq_reads_directory_path
        String sample_name
        File? transcriptome_file_path
        File? probe_set_file_path
        String sample_id
        String bam_file_save  # "true" or "false"
        File dummy_he_image_path
        File dummy_registration_json_file
    }

    command <<<

        gsutil cp -r ~{fastq_reads_directory_path} "/cromwell_root/"

        ls -1 "/cromwell_root/" | head -n 1

        fastq_folder_name=$(basename "$fastq_reads_directory_path")
        fastq_directory_path_in_cromwell="/cromwell_root/$fastq_folder_name"

        transcriptome_directory=$(dirname ~{transcriptome_file_path})
        tar -xzf ~{transcriptome_file_path} -C "$transcriptome_directory"
        unzipped_dir_name=$(basename ~{transcriptome_file_path} .tar.gz)
        unzipped_transcriptome_dir="$transcriptome_directory/$unzipped_dir_name/"

        if [ ~{he_image_path} == ~{dummy_he_image_path} ]; then
            if [ ~{registration_json_file} == ~{dummy_registration_json_file} ]; then
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_directory_path_in_cromwell" \
                        --cytaimage ~{cytassist_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path} \
                        --sample ~{sample_name}
            else
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_directory_path_in_cromwell" \
                        --cytaimage ~{cytassist_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path} \
                        --loupe-alignment ~{registration_json_file} \
                        --sample ~{sample_name}
            fi

        else
            if [ ~{registration_json_file} == ~{dummy_registration_json_file} ]; then
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_directory_path_in_cromwell" \
                        --cytaimage ~{cytassist_image_path} \
                        --image ~{he_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path} \
                        --sample ~{sample_name}
            else
                spaceranger count \
                        --id ~{sample_id} \
                        --fastqs "$fastq_directory_path_in_cromwell" \
                        --cytaimage ~{cytassist_image_path} \
                        --image ~{he_image_path} \
                        --create-bam ~{bam_file_save} \
                        --transcriptome "$unzipped_transcriptome_dir" \
                        --probe-set ~{probe_set_file_path} \
                        --loupe-alignment ~{registration_json_file} \
                        --sample ~{sample_name}
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
        memory: "150GB"
        cpu: 32
        preemptible: 2
        disks: "local-disk 3500 HDD"
    }

}