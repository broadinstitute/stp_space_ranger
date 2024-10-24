version 1.0
task space_ranger {

    input {       
        Array[File] cytassist_image_path
        Array[File] he_image_path
        Array[File] fastq_file_path
        Array[String] bam_file_save
        Array[File] transcriptome_file_path
        Array[File] probe_set_file_path
        Array[String] prefix_list_of_fastqs
        Int index_of_vm
        Int num_files_per_vm
    }

    command <<<

        spaceranger testrun --id=tiny

        # Convert WDL arrays to Bash arrays using 'IFS' and 'read'
        IFS=', ' read -r -a cytassist_image_path_array <<< "~{sep=', ' cytassist_image_path}"
        IFS=', ' read -r -a he_image_path_array <<< "~{sep=', ' he_image_path}"
        IFS=', ' read -r -a fastq_file_path_array <<< "~{sep=', ' fastq_file_path}"
        IFS=', ' read -r -a bam_file_save_array <<< "~{sep=', ' bam_file_save}"
        IFS=', ' read -r -a transcriptome_file_path_array <<< "~{sep=', ' transcriptome_file_path}"
        IFS=', ' read -r -a probe_set_file_path_array <<< "~{sep=', ' probe_set_file_path}"
        IFS=', ' read -r -a prefix_list_of_fastqs_array <<< "~{sep=', ' prefix_list_of_fastqs}"

        # Pre-calculate the start and end indices for slicing
        start_index=$((index_of_vm * num_files_per_vm))
        end_index=$(((index_of_vm + 1) * num_files_per_vm))

        # Perform slicing on the Bash arrays
        sliced_cytassist_image_path=("${cytassist_image_path_array[@]:${start_index}:${end_index}}")
        sliced_he_image_path=("${he_image_path_array[@]:${start_index}:${end_index}}")
        sliced_probe_set_file_path=("${probe_set_file_path_array[@]:${start_index}:${end_index}}")

        # Fastq files are processed in pairs, so calculate appropriate indices
        fastq_start_index=$((start_index * 2))
        fastq_end_index=$((end_index * 2))
        sliced_fastq_file_path=("${fastq_file_path_array[@]:${fastq_start_index}:${fastq_end_index}}")

        sliced_bam_file_save=("${bam_file_save_array[@]:${start_index}:${end_index}}")
        sliced_prefix_list_of_fastqs=("${prefix_list_of_fastqs_array[@]:${start_index}:${end_index}}")

        # Debugging: print the sliced arrays
        echo "Sliced cytassist_image_path: ${sliced_cytassist_image_path[@]}"
        echo "Sliced he_image_path: ${sliced_he_image_path[@]}"
        echo "Sliced probe_set_file_path: ${sliced_probe_set_file_path[@]}"
        echo "Sliced fastq_file_path: ${sliced_fastq_file_path[@]}"
        echo "Sliced bam_file_save: ${sliced_bam_file_save[@]}"
        echo "Sliced prefix_list_of_fastqs: ${sliced_prefix_list_of_fastqs[@]}"

        num_files="${#sliced_cytassist_image_path[@]}"
        echo "Number of files: $num_files"

        for ((i=0; i<num_files; i++)); do

            # Extract fastq file pairs for each iteration
            fastq_file_start=$((i * 2))
            sliced_fastq_file_path_pair=("${sliced_fastq_file_path[@]:${fastq_file_start}:2}")

            sliced_fastq_file_directory=$(dirname "${sliced_fastq_file_path_pair[0]}")

            # Print the fastq file directory for debugging
            echo "Sliced fastq file directory: $sliced_fastq_file_directory"

            # Create transcriptome directory if it doesn't exist
            transcriptome_directory="transcriptome_directory"
            mkdir -p "$transcriptome_directory"

            unzip ~{transcriptome_file_path} -d "$transcriptome_directory"

            # Run spaceranger count command
            spaceranger count \
                --id "${i}" \
                --fastqs "$sliced_fastq_file_directory" \
                --sample "${sliced_prefix_list_of_fastqs[${i}]}" \
                --cytaimage "${sliced_cytassist_image_path[${i}]}" \
                --image "${sliced_he_image_path[${i}]}" \
                --create-bam "${sliced_bam_file_save[${i}]}" \
                --transcriptome "$transcriptome_directory" \
                --probe-set "${sliced_probe_set_file_path[${i}]}"

            echo "spaceranger count completed for iteration $i."

            # Rename output files to avoid overwriting
            mv "/cromwell_root/${i}/outs/binned_outputs.tar.gz" "/cromwell_root/${i}/outs/${i}_binned_outputs.tar.gz"
            mv "/cromwell_root/${i}/outs/cloupe_008um.cloupe" "/cromwell_root/${i}/outs/${i}_cloupe_008um.cloupe"
            mv "/cromwell_root/${i}/outs/feature_slice.h5" "/cromwell_root/${i}/outs/${i}_feature_slice.h5"
            mv "/cromwell_root/${i}/outs/metrics_summary.csv" "/cromwell_root/${i}/outs/${i}_metrics_summary.csv"
            mv "/cromwell_root/${i}/outs/molecule_info.h5" "/cromwell_root/${i}/outs/${i}_molecule_info.h5"
            mv "/cromwell_root/${i}/outs/probe_set.csv" "/cromwell_root/${i}/outs/${i}_probe_set.csv"
            mv "/cromwell_root/${i}/outs/spatial.tar.gz" "/cromwell_root/${i}/outs/${i}_spatial.tar.gz"
            mv "/cromwell_root/${i}/outs/web_summary.html" "/cromwell_root/${i}/outs/${i}_web_summary.html"

        done

    >>>

    output {
        Array[File] cloupe_files = glob("/cromwell_root/*/outs/*.cloupe")
        Array[File] h5_files = glob("/cromwell_root/*/outs/*.h5")
        Array[File] csv_files = glob("/cromwell_root/*/outs/*.csv")
        Array[File] zip_files = glob("/cromwell_root/*/outs/*.tar.gz")
        Array[File] html_files = glob("/cromwell_root/*/outs/*.html")
    }

    runtime {
        docker: "jishar7/space_ranger@sha256:538f88a9f9cfe997b0bf7480fea05a724267c1f13ce1c406e65e16bdcbc8db04"
        memory: "100GB"
        preemptible: 2
        disks: "local-disk 200 HDD"
    }

}