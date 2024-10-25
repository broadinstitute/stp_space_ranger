version 1.0
task space_ranger {

    input {       
        File cytassist_image_path
        File he_image_path
        File fastq_read1_file_path
        File fastq_read2_file_path
        String bam_file_save
        File transcriptome_file_path
        File probe_set_file_path
        String sample_id
    }

    command <<<

        spaceranger testrun --id=tiny

        fastq_files_directory=$(dirname ~{fastq_read1_file_path})

        transcriptome_directory=$(dirname ~{transcriptome_file_path})
        tar -xzf ~{transcriptome_file_path} -C "$transcriptome_directory"
        unzipped_dir_name=$(basename ~{transcriptome_file_path} .tar.gz)
        unzipped_transcriptome_dir="$transcriptome_directory/$unzipped_dir_name/"

        spaceranger count \
                --id ~{sample_id} \
                --fastqs "$fastq_files_directory" \
                --cytaimage ~{cytassist_image_path} \
                --image ~{he_image_path} \
                --create-bam ~{bam_file_save} \
                --transcriptome "$unzipped_transcriptome_dir" \
                --probe-set ~{probe_set_file_path}

        mv "/cromwell_root/~{sample_id}/outs/binned_outputs.tar.gz" "/cromwell_root/~{sample_id}/outs/~{sample_id}_binned_outputs.tar.gz"
        mv "/cromwell_root/~{sample_id}/outs/cloupe_008um.cloupe" "/cromwell_root/~{sample_id}/outs/~{sample_id}_cloupe_008um.cloupe"
        mv "/cromwell_root/~{sample_id}/outs/feature_slice.h5" "/cromwell_root/~{sample_id}/outs/~{sample_id}_feature_slice.h5"
        mv "/cromwell_root/~{sample_id}/outs/metrics_summary.csv" "/cromwell_root/~{sample_id}/outs/~{sample_id}_metrics_summary.csv"
        mv "/cromwell_root/~{sample_id}/outs/molecule_info.h5" "/cromwell_root/~{sample_id}/outs/~{sample_id}_molecule_info.h5"
        mv "/cromwell_root/~{sample_id}/outs/probe_set.csv" "/cromwell_root/~{sample_id}/outs/~{sample_id}_probe_set.csv"
        mv "/cromwell_root/~{sample_id}/outs/spatial.tar.gz" "/cromwell_root/~{sample_id}/outs/~{sample_id}_spatial.tar.gz"
        mv "/cromwell_root/~{sample_id}/outs/web_summary.html" "/cromwell_root/~{sample_id}/outs/~{sample_id}_web_summary.html"

    >>>

    output {
        File cloupe_file = glob("/cromwell_root/*/outs/*.cloupe")[0]
        File h5_file = glob("/cromwell_root/*/outs/*.h5")[0]
        File csv_file = glob("/cromwell_root/*/outs/*.csv")[0]
        File zip_file = glob("/cromwell_root/*/outs/*.tar.gz")[0]
        File html_file = glob("/cromwell_root/*/outs/*.html")[0]
    }

    runtime {
        docker: "jishar7/space_ranger@sha256:538f88a9f9cfe997b0bf7480fea05a724267c1f13ce1c406e65e16bdcbc8db04"
        memory: "130GB"
        cpu: 10
        preemptible: 2
        disks: "local-disk 1000 HDD"
    }

}