version 1.0
task space_ranger {

    input {       

    	Array[File] cytassist_image_path
        Array[File] he_image_path
        Array[File]? registration_json_file_path
        Array[File] fastq_file_dir
        Array[String] bam_file_save
        Array[File] transcriptome_file_path
        Array[File] probe_set_file_path
        Float amount_of_VMs 
        String index_of_vm
        Array[String] prefix_list_of_fastqs

    }

    command <<<

        spaceranger testrun --id=tiny

        num_files = ~{#cytassist_image_path[@]}

        for ((i=0; i<num_files; i++)); do

            fastq_file_dir_pair=("${fastq_file_dir[@]:$((i*2)):$((i+1)*2)}")

            fastq_file_directory=$(dirname "$fastq_file_dir_pair")

            transcriptome_directory="transcriptome_directory"
            mkdir -p "$transcriptome_directory"

            unzip ~{transcriptome_file_path} -d "$transcriptome_directory"

            spaceranger count \
                --id "$i" \
                --fastqs "$fastq_file_directory" \
                --sample ~{prefix_list_of_fastqs[i]} \
                --cytaimage ~{cytassist_image_path[i]} \
                --image ~{he_image_path[i]} \
                --create-bam ~{bam_file_save[i]} \
                --transcriptome "$transcriptome_directory" \
                --probe-set ~{probe_set_file_path[i]}
        done

    >>>

    runtime {
        docker: "jishar7/space_ranger@sha256:538f88a9f9cfe997b0bf7480fea05a724267c1f13ce1c406e65e16bdcbc8db04"
        memory: "100GB"
        preemptible: 2
        disks: "local-disk 200 HDD"
    }

}