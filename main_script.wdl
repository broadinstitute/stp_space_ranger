version 1.0

import "./space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {
    input {
        Float tiles_dimension
        Int slide ID
        Float capture area
        Boolean loupe_alignment # yes or no
    }

    call SPACE_RANGER.space_ranger as space_ranger {input: image_paths_list=image_paths_list,}

    Map[String, Array[Array[Float]]] calling_intervals = read_json(create_subset.intervals)
    Int num_VMs_in_use = round(calling_intervals['number_of_VMs'][0][0])
    
    scatter (i in range(num_VMs_in_use)) {

        String index_for_intervals = "~{i}"

        call CELLPOSE.run_cellpose as run_cellpose {input: 
                        image_path=create_subset.tiled_image,
                        diameter= diameter, 
                        flow_thresh= flow_thresh, 
                        cell_prob_thresh= cell_prob_thresh,
                        dummy_pretrained_model=dummy_pretrained_model,
                        pretrained_model= if defined(pretrained_model) then select_first([pretrained_model]) else dummy_pretrained_model,
                        model_type= if defined(model_type) then select_first([model_type]) else 'None',
                        segment_channel= segment_channel,
                        optional_channel = optional_channel,
                        shard_index=index_for_intervals
                        }
    }

    call MERGE.merge_segmentation_dfs as merge_segmentation_dfs { input: outlines=run_cellpose.outlines,
                intervals=create_subset.intervals,
                original_tile_polygons=create_subset.original_tile_polygons,
                trimmed_tile_polygons=create_subset.trimmed_tile_polygons
    }

    call PARTITION.partitioning_transcript_cell_by_gene as partitioning_transcript_cell_by_gene { 
        input: transcript_file = create_subset.subset_coordinates, 
        cell_polygon_file = merge_segmentation_dfs.processed_cell_polygons,
        pre_merged_cell_polygons = merge_segmentation_dfs.pre_merged_cell_polygons,
        transcript_chunk_size = transcript_chunk_size,
        technology = technology
    }
    
}
